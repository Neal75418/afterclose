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
      if (lower.contains(e.key)) result.add(e.value);
    }
    return result;
  }
}
