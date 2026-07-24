import 'package:afterclose/core/constants/news_heat_params.dart';

/// 從新聞標題匹配台股題材（純函數）
///
/// 字典見 [NewsHeatParams.themes]；英文詞不分大小寫。
class ThemeMatcher {
  ThemeMatcher()
    : _keywordToTheme = {
        for (final e in NewsHeatParams.themes.entries)
          for (final kw in e.value) kw.toLowerCase(): e.key,
      };

  /// 小寫關鍵詞 → 題材名
  final Map<String, String> _keywordToTheme;

  /// 回傳標題命中的題材名集合
  Set<String> match(String title) {
    final lower = title.toLowerCase();
    final result = <String>{};
    for (final e in _keywordToTheme.entries) {
      if (_contains(lower, e.key)) result.add(e.value);
    }
    return result;
  }

  /// ASCII-only 關鍵詞（AI/EV/CPO…）需「兩側非 ASCII 字母」才算命中，
  /// 避免英文子字串誤配（T[ai]wan→AI、7-El[ev]en/r[ev]enue→電動車、
  /// AMC[ev]i→電動車）。含中文的關鍵詞無此問題、直接 contains。
  ///
  /// 只擋**字母**相鄰、放行數字（EV9 這類車款/型號仍命中）與 CJK/標點/
  /// 空白/端點。刻意不用 `\b`——Dart word boundary 對 CJK 邊界不可靠
  /// （見 memory afterclose_news_mapping_context_rule）。
  bool _contains(String haystack, String keyword) {
    final asciiOnly = keyword.codeUnits.every((c) => c < 0x80);
    if (!asciiOnly) return haystack.contains(keyword);
    var idx = haystack.indexOf(keyword);
    while (idx != -1) {
      final before = idx > 0 ? haystack.codeUnitAt(idx - 1) : -1;
      final afterPos = idx + keyword.length;
      final after = afterPos < haystack.length
          ? haystack.codeUnitAt(afterPos)
          : -1;
      if (!_isAsciiLetter(before) && !_isAsciiLetter(after)) return true;
      idx = haystack.indexOf(keyword, idx + 1);
    }
    return false;
  }

  /// haystack 已 toLowerCase → 只需判 a-z
  static bool _isAsciiLetter(int c) => c >= 0x61 && c <= 0x7a;
}
