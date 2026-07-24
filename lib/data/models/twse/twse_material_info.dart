/// TWSE 上市公司每日重大訊息（openapi t187ap04_L）單筆資料
///
/// 中文鍵，且「主旨 」鍵**尾帶空格**（MOPS 匯出陷阱，2026-07-24 對
/// live 端點實證）；值內含 `\r\n`。日期為民國年 `yyyMMdd`、時間為
/// `H..HHmmss`（長度不定，需左補零）。
class TwseMaterialInfo {
  const TwseMaterialInfo({
    required this.code,
    required this.name,
    required this.speakDate,
    required this.speakTime,
    required this.subject,
    required this.description,
  });

  factory TwseMaterialInfo.fromJson(Map<String, dynamic> json) {
    String clean(Object? v) =>
        (v?.toString() ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return TwseMaterialInfo(
      code: json['公司代號']?.toString() ?? '',
      name: json['公司名稱']?.toString() ?? '',
      speakDate: json['發言日期']?.toString() ?? '',
      speakTime: json['發言時間']?.toString() ?? '',
      // 「主旨 」尾空格為主鍵名，防禦性地也接受無空格版本
      subject: clean(json['主旨 '] ?? json['主旨']),
      description: json['說明']?.toString() ?? '',
    );
  }

  final String code;
  final String name;

  /// 發言日期（民國年 yyyMMdd）
  final String speakDate;

  /// 發言時間（Hmmss~HHmmss，未補零）
  final String speakTime;

  /// 主旨（已清理換行）
  final String subject;

  /// 說明全文（保留原始格式，供結構化欄位抽取）
  final String description;

  /// 發言時點轉 UTC——與 RSS 新聞同口徑（news_item.published_at 存
  /// UTC），混存 local 會破壞文字排序。台北 = UTC+8。
  DateTime? get publishedAtUtc {
    final d = _rocToDate(speakDate);
    if (d == null) return null;
    final t = speakTime.padLeft(6, '0');
    final hh = int.tryParse(t.substring(0, 2)) ?? 0;
    final mm = int.tryParse(t.substring(2, 4)) ?? 0;
    final ss = int.tryParse(t.substring(4, 6)) ?? 0;
    return DateTime.utc(
      d.year,
      d.month,
      d.day,
      hh,
      mm,
      ss,
    ).subtract(const Duration(hours: 8));
  }

  /// 是否為法人說明會公告
  bool get isInvestorConference =>
      subject.contains('法人說明會') || description.contains('召開法人說明會');

  static final _confDatePattern = RegExp(
    r'召開法人說明會之日期[：:]\s*(\d{2,3})/(\d{1,2})/(\d{1,2})',
  );

  /// 法說會**開會日**（自「說明」結構化欄位抽取；抽不到回 null）
  DateTime? get conferenceDate {
    final m = _confDatePattern.firstMatch(description);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y + 1911, mo, d);
    if (dt.month != mo || dt.day != d) return null;
    return dt;
  }

  static DateTime? _rocToDate(String roc) {
    if (roc.length < 6 || roc.length > 7) return null;
    final year = int.tryParse(roc.substring(0, roc.length - 4));
    final month = int.tryParse(roc.substring(roc.length - 4, roc.length - 2));
    final day = int.tryParse(roc.substring(roc.length - 2));
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year + 1911, month, day);
    if (dt.month != month || dt.day != day) return null;
    return dt;
  }
}
