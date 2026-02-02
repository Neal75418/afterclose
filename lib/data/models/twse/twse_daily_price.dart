import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/utils/logger.dart';

/// TWSE 每日價格資料
class TwseDailyPrice {
  const TwseDailyPrice({
    required this.date,
    required this.code,
    required this.name,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.change,
  });

  factory TwseDailyPrice.fromJson(Map<String, dynamic> json) {
    final code = json['Code'];
    final dateStr = json['Date'];

    if (code == null || code.toString().isEmpty) {
      throw FormatException('Missing Code', json);
    }
    if (dateStr == null || dateStr.toString().isEmpty) {
      throw FormatException('Missing Date', json);
    }

    // 將民國日期解析為 DateTime
    final date = parseRocDate(dateStr.toString());

    return TwseDailyPrice(
      date: date,
      code: code.toString(),
      name: json['Name']?.toString() ?? '',
      open: _parseDouble(json['OpeningPrice']),
      high: _parseDouble(json['HighestPrice']),
      low: _parseDouble(json['LowestPrice']),
      close: _parseDouble(json['ClosingPrice']),
      volume: _parseDouble(json['TradeVolume']),
      change: _parseDouble(json['Change']),
    );
  }

  static TwseDailyPrice? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseDailyPrice.fromJson(json);
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseDailyPrice 失敗: ${json['Code']}');
      return null;
    }
  }

  final DateTime date;
  final String code;
  final String name;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? change;

  /// 將 TWSE 民國日期（例如 "1150119"）轉換為 DateTime
  ///
  /// 回傳 UTC 午夜時間以確保跨時區一致性
  static DateTime parseRocDate(String rocDate) {
    if (rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }

    final rocYear = int.parse(rocDate.substring(0, 3));
    final month = int.parse(rocDate.substring(3, 5));
    final day = int.parse(rocDate.substring(5, 7));

    // 民國年 + ApiConfig.rocYearOffset = 西元年
    final adYear = rocYear + ApiConfig.rocYearOffset;

    return DateTime(adYear, month, day);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // 移除數字中的逗號（例如 "1,234,567"）
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}
