import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// Service for orchestrating daily market data updates
///
/// Implements the 10-step daily update pipeline:
/// 1. Check trading day
/// 2. Update stock master
/// 3. Fetch daily prices
/// 4. Fetch institutional data (optional)
/// 5. Fetch RSS news
/// 6. Filter candidates (candidate-first)
/// 7. Run analysis
/// 8. Apply rule engine
/// 9. Generate top 10
/// 10. Mark completion
class UpdateService {
  UpdateService({
    required AppDatabase database,
    required StockRepository stockRepository,
    required PriceRepository priceRepository,
    required NewsRepository newsRepository,
    required AnalysisRepository analysisRepository,
    InstitutionalRepository? institutionalRepository,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
  }) : _db = database,
       _stockRepo = stockRepository,
       _priceRepo = priceRepository,
       _newsRepo = newsRepository,
       _analysisRepo = analysisRepository,
       _institutionalRepo = institutionalRepository,
       _analysisService = analysisService ?? const AnalysisService(),
       _ruleEngine = ruleEngine ?? const RuleEngine();

  final AppDatabase _db;
  final StockRepository _stockRepo;
  final PriceRepository _priceRepo;
  final NewsRepository _newsRepo;
  final AnalysisRepository _analysisRepo;
  final InstitutionalRepository? _institutionalRepo;
  final AnalysisService _analysisService;
  final RuleEngine _ruleEngine;

  /// Run the complete daily update pipeline
  ///
  /// Returns [UpdateResult] with details of what was updated
  Future<UpdateResult> runDailyUpdate({
    DateTime? forDate,
    bool forceFetch = false,
    UpdateProgressCallback? onProgress,
  }) async {
    final targetDate = forDate ?? DateTime.now();
    final normalizedDate = _normalizeDate(targetDate);

    // Create update run record
    final runId = await _db.createUpdateRun(
      normalizedDate,
      UpdateStatus.partial.code,
    );

    final result = UpdateResult(date: normalizedDate);

    try {
      // Step 1: Check if trading day
      onProgress?.call(1, 10, '檢查交易日');
      if (!forceFetch && !_isTradingDay(targetDate)) {
        result.skipped = true;
        result.message = '非交易日，跳過更新';
        await _db.finishUpdateRun(
          runId,
          UpdateStatus.success.code,
          message: result.message,
        );
        return result;
      }

      // Step 2: Update stock master (weekly is enough)
      onProgress?.call(2, 10, '更新股票清單');
      if (forceFetch || _shouldUpdateStockList(targetDate)) {
        try {
          final stockCount = await _stockRepo.syncStockList();
          result.stocksUpdated = stockCount;
        } catch (e) {
          result.errors.add('股票清單更新失敗: $e');
        }
      }

      // Step 3: Fetch daily prices
      onProgress?.call(3, 10, '取得價格資料');
      try {
        final priceCount = await _priceRepo.syncTodayPrices(
          date: normalizedDate,
        );
        result.pricesUpdated = priceCount;
      } catch (e) {
        result.errors.add('價格資料更新失敗: $e');
      }

      // Step 4: Fetch institutional data (optional)
      onProgress?.call(4, 10, '取得法人資料');
      final institutionalRepo = _institutionalRepo;
      if (institutionalRepo != null) {
        try {
          // Sync for watchlist stocks only to save API calls
          final watchlist = await _db.getWatchlist();
          for (final item in watchlist) {
            await institutionalRepo.syncInstitutionalData(
              item.symbol,
              startDate: normalizedDate.subtract(const Duration(days: 5)),
              endDate: normalizedDate,
            );
          }
          result.institutionalUpdated = watchlist.length;
        } catch (e) {
          result.errors.add('法人資料更新失敗: $e');
        }
      }

      // Step 5: Fetch RSS news
      onProgress?.call(5, 10, '取得新聞資料');
      try {
        final newsResult = await _newsRepo.syncNews();
        result.newsUpdated = newsResult.itemsAdded;
        if (newsResult.hasErrors) {
          for (final error in newsResult.errors) {
            result.errors.add('RSS 錯誤: $error');
          }
        }
      } catch (e) {
        result.errors.add('新聞更新失敗: $e');
      }

      // Step 6: Filter candidates
      onProgress?.call(6, 10, '篩選候選股票');
      final candidates = await _filterCandidates(normalizedDate);
      result.candidatesFound = candidates.length;

      // Step 7-8: Run analysis and apply rule engine
      onProgress?.call(7, 10, '執行分析');
      final scoredStocks = await _analyzeAndScore(
        candidates,
        normalizedDate,
        onProgress: (current, total) {
          onProgress?.call(7, 10, '分析中 ($current/$total)');
        },
      );
      result.stocksAnalyzed = scoredStocks.length;

      // Step 9: Generate top 10 recommendations
      onProgress?.call(9, 10, '產生推薦');
      await _generateRecommendations(scoredStocks, normalizedDate);
      result.recommendationsGenerated = scoredStocks
          .take(RuleParams.dailyTopN)
          .length;

      // Step 10: Mark completion
      onProgress?.call(10, 10, '完成');
      final status = result.errors.isEmpty
          ? UpdateStatus.success.code
          : UpdateStatus.partial.code;

      await _db.finishUpdateRun(
        runId,
        status,
        message: result.errors.isEmpty ? '更新完成' : '部分更新成功',
      );

      result.success = true;
      result.message = '更新完成';

      return result;
    } catch (e) {
      result.success = false;
      result.message = '更新失敗: $e';
      result.errors.add(e.toString());

      await _db.finishUpdateRun(
        runId,
        UpdateStatus.failed.code,
        message: result.message,
      );

      return result;
    }
  }

  /// Filter stocks that meet candidate criteria
  Future<List<String>> _filterCandidates(DateTime date) async {
    final candidates = <String>[];
    final allStocks = await _stockRepo.getAllStocks();

    // Calculate date range for price history
    final startDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );

    for (final stock in allStocks) {
      final prices = await _priceRepo.getPriceHistory(
        stock.symbol,
        startDate: startDate,
        endDate: date,
      );

      if (prices.isEmpty) continue;

      // Check if meets candidate criteria
      if (_analysisService.isCandidate(prices)) {
        candidates.add(stock.symbol);
      }
    }

    return candidates;
  }

  /// Analyze candidates and calculate scores
  Future<List<ScoredStock>> _analyzeAndScore(
    List<String> candidates,
    DateTime date, {
    void Function(int current, int total)? onProgress,
  }) async {
    final scoredStocks = <ScoredStock>[];

    // Get recently recommended symbols for cooldown check
    final recentlyRecommended = await _analysisRepo
        .getRecentlyRecommendedSymbols();

    final startDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );

    for (var i = 0; i < candidates.length; i++) {
      final symbol = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      // Get price history
      final prices = await _priceRepo.getPriceHistory(
        symbol,
        startDate: startDate,
        endDate: date,
      );

      if (prices.length < RuleParams.swingWindow) continue;

      // Run analysis
      final analysisResult = _analysisService.analyzeStock(prices);
      if (analysisResult == null) continue;

      // Build context for rule engine
      final context = _analysisService.buildContext(analysisResult);

      // Get optional data
      List<DailyInstitutionalEntry>? institutionalHistory;
      final instRepo = _institutionalRepo;
      if (instRepo != null) {
        institutionalHistory = await instRepo.getInstitutionalHistory(
          symbol,
          days: 10,
        );
      }

      final recentNews = await _newsRepo.getNewsForStock(symbol, days: 2);

      // Run rule engine
      final reasons = _ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        institutionalHistory: institutionalHistory,
        recentNews: recentNews,
      );

      if (reasons.isEmpty) continue;

      // Calculate score
      final wasRecent = recentlyRecommended.contains(symbol);
      final score = _ruleEngine.calculateScore(
        reasons,
        wasRecentlyRecommended: wasRecent,
      );

      // Get top reasons
      final topReasons = _ruleEngine.getTopReasons(reasons);

      // Save analysis result
      await _analysisRepo.saveAnalysis(
        symbol: symbol,
        date: date,
        trendState: analysisResult.trendState.code,
        reversalState: analysisResult.reversalState.code,
        supportLevel: analysisResult.supportLevel,
        resistanceLevel: analysisResult.resistanceLevel,
        score: score.toDouble(),
      );

      // Save reasons
      await _analysisRepo.saveReasons(
        symbol,
        date,
        topReasons
            .map(
              (r) => ReasonData(
                type: r.type.code,
                evidenceJson: r.evidenceJson,
                score: r.score,
              ),
            )
            .toList(),
      );

      scoredStocks.add(
        ScoredStock(symbol: symbol, score: score, reasons: topReasons),
      );
    }

    // Sort by score descending
    scoredStocks.sort((a, b) => b.score.compareTo(a.score));

    return scoredStocks;
  }

  /// Generate and save daily recommendations
  Future<void> _generateRecommendations(
    List<ScoredStock> scoredStocks,
    DateTime date,
  ) async {
    // Take top N
    final topN = scoredStocks.take(RuleParams.dailyTopN).toList();

    // Save recommendations
    await _analysisRepo.saveRecommendations(
      date,
      topN
          .map(
            (s) =>
                RecommendationData(symbol: s.symbol, score: s.score.toDouble()),
          )
          .toList(),
    );
  }

  /// Check if date is a trading day (Taiwan market)
  bool _isTradingDay(DateTime date) {
    // Skip weekends
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }

    // TODO: Add Taiwan stock market holiday calendar
    // For now, assume all weekdays are trading days

    return true;
  }

  /// Check if stock list should be updated (weekly)
  bool _shouldUpdateStockList(DateTime date) {
    // Update on Mondays or if never updated
    return date.weekday == DateTime.monday;
  }

  /// Normalize date to start of day in UTC
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}

/// Callback for update progress
typedef UpdateProgressCallback =
    void Function(int currentStep, int totalSteps, String message);

/// Result of daily update
class UpdateResult {
  UpdateResult({required this.date});

  final DateTime date;
  bool success = false;
  bool skipped = false;
  String? message;
  int stocksUpdated = 0;
  int pricesUpdated = 0;
  int institutionalUpdated = 0;
  int newsUpdated = 0;
  int candidatesFound = 0;
  int stocksAnalyzed = 0;
  int recommendationsGenerated = 0;
  List<String> errors = [];

  /// Summary message
  String get summary {
    if (skipped) return message ?? '跳過更新';
    if (!success) return '更新失敗: ${errors.join(', ')}';

    return '分析 $stocksAnalyzed 檔，產生 $recommendationsGenerated 個推薦';
  }
}

/// Stock with calculated score
class ScoredStock {
  const ScoredStock({
    required this.symbol,
    required this.score,
    required this.reasons,
  });

  final String symbol;
  final int score;
  final List<TriggeredReason> reasons;
}
