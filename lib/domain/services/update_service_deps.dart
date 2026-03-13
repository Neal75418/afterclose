import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/domain/services/scoring_service.dart';

/// Grouped repository dependencies for [UpdateService]
class UpdateRepositories {
  const UpdateRepositories({
    required this.stock,
    required this.price,
    required this.news,
    required this.analysis,
    this.institutional,
    this.marketData,
    this.trading,
    this.shareholding,
    this.fundamental,
    this.insider,
  });

  final StockRepository stock;
  final PriceRepository price;
  final NewsRepository news;
  final AnalysisRepository analysis;
  final InstitutionalRepository? institutional;
  final MarketDataRepository? marketData;
  final TradingRepository? trading;
  final ShareholdingRepository? shareholding;
  final FundamentalRepository? fundamental;
  final InsiderRepository? insider;
}

/// External API client dependencies for [UpdateService]
class UpdateClients {
  const UpdateClients({this.twse, this.tpex, this.tdcc});

  final TwseClient? twse;
  final TpexClient? tpex;
  final TdccClient? tdcc;
}

/// Optional service overrides for [UpdateService]
class UpdateServices {
  const UpdateServices({
    this.analysis,
    this.ruleEngine,
    this.scoring,
    this.ruleAccuracy,
  });

  final AnalysisService? analysis;
  final RuleEngine? ruleEngine;
  final ScoringService? scoring;
  final RuleAccuracyService? ruleAccuracy;
}
