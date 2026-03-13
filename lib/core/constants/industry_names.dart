/// FinMind API 產業名稱正規化對照表
///
/// TPEx 同一產業可能以不同名稱出現（如「其他電子業」vs「其他電子類」）。
/// 此表將不同變體統一為 canonical 名稱，供 sync 寫入 DB 和查詢時合併使用。
abstract final class IndustryNames {
  static const normalizationMap = <String, String>{
    '其他電子業': '其他電子類',
    '居家生活': '居家生活類',
    '數位雲端': '數位雲端類',
    '綠能環保': '綠能環保類',
    '運動休閒': '運動休閒類',
    '觀光事業': '觀光餐旅類',
    '觀光餐旅': '觀光餐旅類',
    '農業科技': '農業科技業',
  };

  /// 正規化產業名稱，若不在對照表中則原值回傳
  static String normalize(String raw) => normalizationMap[raw] ?? raw;
}
