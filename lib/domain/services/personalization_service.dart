import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 互動類型
enum InteractionType {
  /// 查看股票詳情
  view('VIEW'),

  /// 加入自選股
  addWatchlist('ADD_WATCHLIST'),

  /// 移除自選股
  removeWatchlist('REMOVE_WATCHLIST'),

  /// 加入持倉
  addPosition('ADD_POSITION');

  const InteractionType(this.value);
  final String value;
}

/// 偏好類型
enum PreferenceType {
  /// 產業偏好
  industry('INDUSTRY'),

  /// 市值偏好
  marketCap('MARKET_CAP'),

  /// 風格偏好（成長/價值）
  style('STYLE');

  const PreferenceType(this.value);
  final String value;
}

/// 用戶偏好資料
class UserPreferences {
  const UserPreferences({
    this.industryWeights = const {},
    this.marketCapWeights = const {},
    this.styleWeights = const {},
  });

  /// 產業權重 Map<產業名稱, 權重>
  final Map<String, double> industryWeights;

  /// 市值權重 Map<市值類別, 權重>
  final Map<String, double> marketCapWeights;

  /// 風格權重 Map<風格類別, 權重>
  final Map<String, double> styleWeights;

  /// 是否有足夠的偏好資料
  bool get hasPreferences =>
      industryWeights.isNotEmpty ||
      marketCapWeights.isNotEmpty ||
      styleWeights.isNotEmpty;
}

/// 個人化推薦服務（Sprint 11）
///
/// 負責記錄使用者行為、分析偏好、計算個人化加成分數。
class PersonalizationService {
  PersonalizationService({
    required AppDatabase database,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock;

  final AppDatabase _db;
  final AppClock _clock;

  static const String _logTag = 'Personalization';

  /// 最大個人化加成分數
  static const double maxPersonalizedBonus = 10.0;

  /// 最少互動次數才計入偏好
  static const int minInteractionsForPreference = 3;

  /// 記錄使用者互動
  ///
  /// [type] 互動類型
  /// [symbol] 股票代碼
  /// [durationSeconds] 停留時間（秒），僅 VIEW 類型使用
  /// [sourcePage] 來源頁面
  Future<void> trackInteraction({
    required InteractionType type,
    required String symbol,
    int? durationSeconds,
    String? sourcePage,
  }) async {
    try {
      await _db
          .into(_db.userInteraction)
          .insert(
            UserInteractionCompanion.insert(
              interactionType: type.value,
              symbol: symbol,
              durationSeconds: Value(durationSeconds),
              sourcePage: Value(sourcePage),
            ),
          );

      AppLogger.debug(
        _logTag,
        '記錄互動：${type.value} - $symbol (來源: $sourcePage)',
      );
    } catch (e) {
      AppLogger.warning(_logTag, '記錄互動失敗', e);
    }
  }

  /// 分析使用者偏好
  ///
  /// 從過去 30 天的互動記錄中分析使用者的產業、市值、風格偏好。
  Future<UserPreferences> analyzePreferences() async {
    try {
      final thirtyDaysAgo = _clock.now().subtract(const Duration(days: 30));

      // 取得過去 30 天的互動記錄
      final interactions =
          await (_db.select(_db.userInteraction)
                ..where((t) => t.timestamp.isBiggerOrEqualValue(thirtyDaysAgo))
                ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
              .get();

      if (interactions.isEmpty) {
        return const UserPreferences();
      }

      // 計算每支股票的互動分數
      final symbolScores = <String, double>{};
      for (final interaction in interactions) {
        final score = _calculateInteractionScore(interaction);
        symbolScores.update(
          interaction.symbol,
          (existing) => existing + score,
          ifAbsent: () => score,
        );
      }

      // 取得股票基本資訊以分析偏好
      final symbols = symbolScores.keys.toList();
      final stocks = await (_db.select(
        _db.stockMaster,
      )..where((t) => t.symbol.isIn(symbols))).get();

      // 計算產業偏好
      final industryWeights = <String, double>{};
      for (final stock in stocks) {
        if (stock.industry != null && stock.industry!.isNotEmpty) {
          final score = symbolScores[stock.symbol] ?? 0;
          industryWeights.update(
            stock.industry!,
            (existing) => existing + score,
            ifAbsent: () => score,
          );
        }
      }

      // 正規化權重
      _normalizeWeights(industryWeights);

      // 儲存偏好到資料庫
      await _savePreferences(PreferenceType.industry, industryWeights);

      AppLogger.info(_logTag, '偏好分析完成：產業偏好 ${industryWeights.length} 項');

      return UserPreferences(industryWeights: industryWeights);
    } catch (e, stack) {
      AppLogger.error(_logTag, '分析偏好失敗', e, stack);
      return const UserPreferences();
    }
  }

  /// 計算個人化加成分數
  ///
  /// 根據使用者偏好為股票計算加成分數（0 ~ [maxPersonalizedBonus]）。
  double calculatePersonalizedBonus(
    String symbol,
    UserPreferences prefs,
    StockMasterEntry? stock,
  ) {
    if (!prefs.hasPreferences || stock == null) return 0;

    var bonus = 0.0;

    // 產業加成（目前主要偏好來源）
    if (stock.industry != null &&
        prefs.industryWeights.containsKey(stock.industry)) {
      bonus += prefs.industryWeights[stock.industry]! * maxPersonalizedBonus;
    }

    return bonus.clamp(0, maxPersonalizedBonus);
  }

  /// 取得使用者偏好（從資料庫讀取已計算的偏好）
  Future<UserPreferences> getPreferences() async {
    try {
      final entries = await _db.select(_db.userPreference).get();

      final industryWeights = <String, double>{};
      final marketCapWeights = <String, double>{};
      final styleWeights = <String, double>{};

      for (final entry in entries) {
        switch (entry.preferenceType) {
          case 'INDUSTRY':
            industryWeights[entry.preferenceValue] = entry.weight;
          case 'MARKET_CAP':
            marketCapWeights[entry.preferenceValue] = entry.weight;
          case 'STYLE':
            styleWeights[entry.preferenceValue] = entry.weight;
        }
      }

      return UserPreferences(
        industryWeights: industryWeights,
        marketCapWeights: marketCapWeights,
        styleWeights: styleWeights,
      );
    } catch (e) {
      AppLogger.warning(_logTag, '取得偏好失敗', e);
      return const UserPreferences();
    }
  }

  /// 取得最近互動的股票（用於「最近瀏覽」功能）
  Future<List<String>> getRecentlyViewedSymbols({int limit = 10}) async {
    try {
      final results = await _db
          .customSelect(
            '''
        SELECT DISTINCT symbol
        FROM user_interaction
        WHERE interaction_type = 'VIEW'
        ORDER BY timestamp DESC
        LIMIT ?
        ''',
            variables: [Variable.withInt(limit)],
          )
          .get();

      return results.map((row) => row.read<String>('symbol')).toList();
    } catch (e) {
      AppLogger.warning(_logTag, '取得最近瀏覽失敗', e);
      return [];
    }
  }

  /// 清除過期的互動記錄（保留最近 90 天）
  Future<int> cleanupOldInteractions() async {
    try {
      final ninetyDaysAgo = _clock.now().subtract(const Duration(days: 90));
      final deleted = await (_db.delete(
        _db.userInteraction,
      )..where((t) => t.timestamp.isSmallerThanValue(ninetyDaysAgo))).go();

      if (deleted > 0) {
        AppLogger.info(_logTag, '清除 $deleted 筆過期互動記錄');
      }
      return deleted;
    } catch (e) {
      AppLogger.warning(_logTag, '清除過期互動記錄失敗', e);
      return 0;
    }
  }

  /// 計算單次互動的分數
  double _calculateInteractionScore(UserInteractionEntry interaction) {
    // 基礎分數依互動類型
    final baseScore = switch (interaction.interactionType) {
      'VIEW' => 1.0,
      'ADD_WATCHLIST' => 3.0,
      'REMOVE_WATCHLIST' => -1.0,
      'ADD_POSITION' => 5.0,
      _ => 0.5,
    };

    // VIEW 類型依停留時間加成
    if (interaction.interactionType == 'VIEW' &&
        interaction.durationSeconds != null) {
      final durationBonus = (interaction.durationSeconds! / 60).clamp(0.0, 2.0);
      return baseScore + durationBonus;
    }

    return baseScore;
  }

  /// 正規化權重到 0-1 範圍
  void _normalizeWeights(Map<String, double> weights) {
    if (weights.isEmpty) return;

    final maxWeight = weights.values.reduce((a, b) => a > b ? a : b);
    if (maxWeight <= 0) return;

    for (final key in weights.keys.toList()) {
      weights[key] = weights[key]! / maxWeight;
    }
  }

  /// 儲存偏好到資料庫
  Future<void> _savePreferences(
    PreferenceType type,
    Map<String, double> weights,
  ) async {
    for (final entry in weights.entries) {
      await _db
          .into(_db.userPreference)
          .insertOnConflictUpdate(
            UserPreferenceCompanion.insert(
              preferenceType: type.value,
              preferenceValue: entry.key,
              weight: Value(entry.value),
            ),
          );
    }
  }
}
