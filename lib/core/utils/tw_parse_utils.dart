import 'package:afterclose/core/constants/api_config.dart';

/// 台灣股市 API 回應的共用解析工具
///
/// 提供 TWSE 與 TPEX API 回應中常見的日期與數字格式解析。
/// 統一由 [TwseClient] 和 [TpexClient] 使用，避免重複邏輯。
abstract final class TwParseUtils {
  /// 解析含逗號的數字字串（例如 "1,234,567"）
  ///
  /// 支援 TWSE/TPEX 回傳的各種格式：
  /// - "1,234,567" → 1234567.0
  /// - "--" / "X" / "---" → null
  /// - null / 空字串 → null
  static double? parseFormattedDouble(dynamic value) {
    if (value == null) return null;
    final str = value.toString().replaceAll(',', '').trim();
    if (str.isEmpty || str == '--' || str == 'X' || str == '---') return null;
    return double.tryParse(str);
  }

  /// 解析 YYYYMMDD 格式的西元日期（例如 "20260121"）
  ///
  /// 回傳本地時間午夜以匹配資料庫儲存格式。
  /// 無效格式時回傳今日午夜。
  static DateTime parseAdDate(String dateStr) {
    if (dateStr.length != 8) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
  }

  /// 解析含斜線的民國日期（例如 "115/01/02"）
  ///
  /// 包含日期驗證（月份 1-12、日期不被正規化）。
  /// 無效日期時回傳 null，由呼叫端決定如何處理。
  static DateTime? parseSlashRocDate(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;

    final rocYear = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (rocYear == null || month == null || day == null) return null;
    if (rocYear <= 0 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
    // 驗證日期未被正規化（例如 2/30 會變成 3/2，表示原始日期無效）
    if (date.month != month || date.day != day) return null;
    return date;
  }

  /// 解析緊湊格式民國日期（例如 "1150120" → 民國 115 年 01 月 20 日）
  ///
  /// 包含完整日期驗證。無效日期時回傳 null。
  static DateTime? parseCompactRocDate(String? dateStr) {
    if (dateStr == null || dateStr.length < 7) return null;

    final rocYear = int.tryParse(dateStr.substring(0, 3));
    final month = int.tryParse(dateStr.substring(3, 5));
    final day = int.tryParse(dateStr.substring(5, 7));

    if (rocYear == null || month == null || day == null) return null;
    if (rocYear <= 0 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  /// 將 DateTime 轉為民國日期字串（格式: "114/01/24"）
  static String toRocDateString(DateTime date) {
    final rocYear = date.year - ApiConfig.rocYearOffset;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$rocYear/$month/$day';
  }

  /// 格式化日期為 ISO 風格字串（"2024-01-24"）
  static String formatDateYmd(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
