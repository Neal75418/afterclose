import 'package:afterclose/data/database/app_database.dart';

// ==================================================
// Isolate 序列化 Extension Methods
// ==================================================

/// [DailyPriceEntry] → Isolate 安全 Map
extension DailyPriceIsolateExt on DailyPriceEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'date': date.toIso8601String(),
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'volume': volume,
    'priceChange': priceChange,
  };
}

/// [DailyInstitutionalEntry] → Isolate 安全 Map
extension DailyInstitutionalIsolateExt on DailyInstitutionalEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'date': date.toIso8601String(),
    'foreignNet': foreignNet,
    'investmentTrustNet': investmentTrustNet,
    'dealerNet': dealerNet,
  };
}

/// [NewsItemEntry] → Isolate 安全 Map
extension NewsItemIsolateExt on NewsItemEntry {
  Map<String, dynamic> toIsolateMap() => {
    'id': id,
    'source': source,
    'title': title,
    'url': url,
    'category': category,
    'publishedAt': publishedAt.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'content': content,
  };
}

/// [MonthlyRevenueEntry] → Isolate 安全 Map
extension MonthlyRevenueIsolateExt on MonthlyRevenueEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'date': date.toIso8601String(),
    'revenueYear': revenueYear,
    'revenueMonth': revenueMonth,
    'revenue': revenue,
    'momGrowth': momGrowth,
    'yoyGrowth': yoyGrowth,
  };
}

/// [StockValuationEntry] → Isolate 安全 Map
extension StockValuationIsolateExt on StockValuationEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'date': date.toIso8601String(),
    'per': per,
    'pbr': pbr,
    'dividendYield': dividendYield,
  };
}

/// [FinancialDataEntry] → Isolate 安全 Map
extension FinancialDataIsolateExt on FinancialDataEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'date': date.toIso8601String(),
    'statementType': statementType,
    'dataType': dataType,
    'value': value,
    'originName': originName,
  };
}

/// [DividendHistoryEntry] → Isolate 安全 Map
extension DividendHistoryIsolateExt on DividendHistoryEntry {
  Map<String, dynamic> toIsolateMap() => {
    'symbol': symbol,
    'year': year,
    'cashDividend': cashDividend,
    'stockDividend': stockDividend,
    'exDividendDate': exDividendDate,
    'exRightsDate': exRightsDate,
  };
}

// ==================================================
// Isolate 反序列化 Static Methods
// ==================================================

/// Isolate 邊界 Map → Drift Entry 的靜態反序列化方法集合
abstract final class IsolateMappers {
  /// Map → [DailyPriceEntry]
  static DailyPriceEntry dailyPrice(Map<String, dynamic> map) {
    return DailyPriceEntry(
      symbol: map['symbol'] as String,
      date: DateTime.parse(map['date'] as String),
      open: map['open'] as double?,
      high: map['high'] as double?,
      low: map['low'] as double?,
      close: map['close'] as double?,
      volume: map['volume'] as double?,
      priceChange: map['priceChange'] as double?,
    );
  }

  /// Map → [DailyInstitutionalEntry]
  static DailyInstitutionalEntry dailyInstitutional(Map<String, dynamic> map) {
    return DailyInstitutionalEntry(
      symbol: map['symbol'] as String,
      date: DateTime.parse(map['date'] as String),
      foreignNet: map['foreignNet'] as double?,
      investmentTrustNet: map['investmentTrustNet'] as double?,
      dealerNet: map['dealerNet'] as double?,
    );
  }

  /// Map → [NewsItemEntry]
  static NewsItemEntry newsItem(Map<String, dynamic> map) {
    return NewsItemEntry(
      id: map['id'] as String,
      source: map['source'] as String,
      title: map['title'] as String,
      url: map['url'] as String,
      category: map['category'] as String,
      publishedAt: DateTime.parse(map['publishedAt'] as String),
      fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      content: map['content'] as String?,
    );
  }

  /// Map → [MonthlyRevenueEntry]
  static MonthlyRevenueEntry monthlyRevenue(Map<String, dynamic> map) {
    return MonthlyRevenueEntry(
      symbol: map['symbol'] as String,
      date: DateTime.parse(map['date'] as String),
      revenueYear: map['revenueYear'] as int,
      revenueMonth: map['revenueMonth'] as int,
      revenue: (map['revenue'] as num).toDouble(),
      momGrowth: map['momGrowth'] as double?,
      yoyGrowth: map['yoyGrowth'] as double?,
    );
  }

  /// Map → [StockValuationEntry]
  static StockValuationEntry stockValuation(Map<String, dynamic> map) {
    return StockValuationEntry(
      symbol: map['symbol'] as String,
      date: DateTime.parse(map['date'] as String),
      per: map['per'] as double?,
      pbr: map['pbr'] as double?,
      dividendYield: map['dividendYield'] as double?,
    );
  }

  /// Map → [FinancialDataEntry]
  static FinancialDataEntry financialData(Map<String, dynamic> map) {
    return FinancialDataEntry(
      symbol: map['symbol'] as String,
      date: DateTime.parse(map['date'] as String),
      statementType: map['statementType'] as String,
      dataType: map['dataType'] as String,
      value: map['value'] as double?,
      originName: map['originName'] as String?,
    );
  }

  /// Map → [DividendHistoryEntry]
  static DividendHistoryEntry dividendHistory(Map<String, dynamic> map) {
    return DividendHistoryEntry(
      symbol: map['symbol'] as String,
      year: map['year'] as int,
      cashDividend: (map['cashDividend'] as num).toDouble(),
      stockDividend: (map['stockDividend'] as num).toDouble(),
      exDividendDate: map['exDividendDate'] as String?,
      exRightsDate: map['exRightsDate'] as String?,
    );
  }
}
