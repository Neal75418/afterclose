# 新聞熱度發現層 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 從近期新聞標題分析主流族群與焦點股（提及熱度＋三模式交叉），呈現於新聞頁「熱度分析」Tab，並每日快照提及數供未來回測；名稱匹配結果不進評分。

**Architecture:** 純函數三件組（StockNameMatcher／ThemeMatcher／HeatCalculator）→ 顯示層 provider 即時計算近 28 天標題；每日更新尾端 fail-safe 寫 `news_mention_daily` 快照（唯一消費者是未來回測）。匹配結果**永不寫 `news_stock_map`**。

**Tech Stack:** Flutter/Dart 3、drift（SQLite）、Riverpod、mocktail。

**Spec:** `docs/superpowers/specs/2026-07-15-news-heat-discovery-design.md`

## Global Constraints

- 所有門檻／字典集中 `lib/core/constants/news_heat_params.dart`，禁魔術數字
- 名稱匹配結果不寫 `news_stock_map`（不進 NewsRelatedRule／BatchDataLoader）
- 快照寫入 fail-safe：例外只 `AppLogger.warning`，不中斷更新
- schema 變動必須 bump `app_database.dart` 的 `_schemaFingerprint`；`news_mention_daily` 必須加入 `_userInputTableNames`（歷史不可重建，不得被 fingerprint reset 洗掉）
- 每個 task：測試先紅後綠、`flutter test` 全套綠才 commit、Conventional Commits（繁中）、commit footer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- 測試慣例遵循 `CLAUDE.md`（widget 測試 `setupTestLocalization()`、每檔自宣告 mocks）

---

### Task 1: NewsHeatParams 常數 + StockNameMatcher（純函數）

**Files:**
- Create: `lib/core/constants/news_heat_params.dart`
- Create: `lib/domain/services/news/stock_name_matcher.dart`
- Test: `test/domain/services/news/stock_name_matcher_test.dart`

**Interfaces:**
- Consumes: `StockMasterEntry`（drift 生成，欄位 `symbol`, `name`）
- Produces:
  - `NewsHeatParams.twoCharNameWhitelist: Set<String>`、`NewsHeatParams.dictionaryVersion: int`
  - `StockNameMatcher.fromStocks(List<StockMasterEntry> stocks): StockNameMatcher`
  - `StockNameMatcher.match(String title): Set<String>`（回 symbol 集合，per-article 去重）

- [ ] **Step 1: 寫失敗測試**

```dart
// test/domain/services/news/stock_name_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';

StockMasterEntry stock(String symbol, String name) => StockMasterEntry(
  symbol: symbol,
  name: name,
  market: 'TWSE',
  industry: '電子工業',
  isActive: true,
  updatedAt: DateTime(2026, 7, 15),
);

void main() {
  late StockNameMatcher matcher;

  setUp(() {
    matcher = StockNameMatcher.fromStocks([
      stock('2330', '台積電'),
      stock('2603', '長榮'), // 2 字、在白名單
      stock('2618', '長榮航'), // 3 字
      stock('2454', '聯發科'),
      stock('1210', '大成'), // 2 字、不在白名單
      stock('2317', '鴻海'), // 2 字、在白名單
      stock('3665', '貿聯-KY'),
      stock('2882', '國泰金'),
    ]);
  });

  test('3 字以上名稱直接匹配', () {
    expect(matcher.match('台積電法說會登場'), {'2330'});
  });

  test('最長優先：長榮航不重複計入長榮', () {
    expect(matcher.match('長榮航獲利創高'), {'2618'});
  });

  test('位置消耗後其餘出現仍可匹配：標題同時有長榮航與長榮', () {
    expect(matcher.match('長榮航與長榮海運齊漲'), {'2618', '2603'});
  });

  test('聯發科不會讓白名單外的子字串重複計分', () {
    // 聯發科匹配後消耗位置；「聯發」非獨立出現
    expect(matcher.match('聯發科營收創高'), {'2454'});
  });

  test('2 字名僅白名單匹配：鴻海可、大成不可', () {
    expect(matcher.match('鴻海進軍機器人'), {'2317'});
    expect(matcher.match('明基材料醫材將成最大成長動能'), isEmpty);
  });

  test('-KY 名稱照原樣匹配', () {
    expect(matcher.match('貿聯-KY 6月營收85.18億元'), {'3665'});
  });

  test('同篇多次出現計 1（Set 語意）', () {
    expect(matcher.match('台積電漲！台積電再創高'), {'2330'});
  });

  test('無命中回空集合', () {
    expect(matcher.match('今彩539頭獎開出'), isEmpty);
  });

  test('金融股 3 字名', () {
    expect(matcher.match('國泰金股東會通過配息'), {'2882'});
  });
}
```

- [ ] **Step 2: 跑測試確認紅**

Run: `flutter test test/domain/services/news/stock_name_matcher_test.dart`
Expected: FAIL（`stock_name_matcher.dart` 不存在，compile error）

- [ ] **Step 3: 寫常數檔**

```dart
// lib/core/constants/news_heat_params.dart
/// 新聞熱度發現層參數（名稱白名單／題材字典／熱度門檻）
///
/// Used by: stock_name_matcher.dart, theme_matcher.dart, heat_calculator.dart,
/// news_mention_snapshot_service.dart
abstract final class NewsHeatParams {
  /// 字典版本：白名單或題材字典**語意性異動**時遞增。
  /// 寫進 news_mention_daily 快照，供未來回測取同版本區段
  /// （避免字典演化造成的假爆量）。
  static const int dictionaryVersion = 1;

  /// 熱度近窗（天）
  static const int recentWindowDays = 7;

  /// 熱度基準窗（天）：近窗之前的 N 天
  static const int baselineWindowDays = 21;

  /// 爆量最低篇數（防低基數假爆量）
  static const int surgeMinMentions = 3;

  /// 主流族群顯示數
  static const int topThemesCount = 8;

  /// 焦點股顯示數
  static const int topStocksCount = 20;

  /// 族群卡片成分股顯示數
  static const int themeTopStocksCount = 5;

  /// 快照回補天數（晚到新聞自我修正）
  static const int snapshotBackfillDays = 3;

  /// 2 字公司簡稱白名單（Task 2 語料稽核後定稿——此為初始候選，
  /// 稽核發現誤配即移除並記錄於 commit message）
  ///
  /// 排除示例（語料實證誤配）：大成（最大成長）、上海（城市）、
  /// 三星（韓國三星）、世界（普通名詞）、中興（中興大學/中興電子字串）。
  static const Set<String> twoCharNameWhitelist = {
    '鴻海', '聯電', '台塑', '廣達', '緯創', '華碩', '群創', '友達',
    '國巨', '華航', '陽明', '長榮', '萬海', '中鋼', '台泥', '亞泥',
    '台化', '南亞', '台達', '和碩', '仁寶', '英韌', '智邦', '光寶',
    '研華', '威剛', '南電', '景碩', '欣興', '健鼎', '金像', '嘉澤',
  };

  /// 台股題材字典：題材名 → 同義詞組（標題含任一詞即命中該題材）。
  /// 英文詞不分大小寫。新題材手動加詞後 bump [dictionaryVersion]。
  static const Map<String, List<String>> themes = {
    'AI': ['AI', '人工智慧', 'AI伺服器', 'AI 伺服器'],
    '記憶體': ['記憶體', 'DRAM', 'NAND', 'HBM'],
    '半導體設備': ['半導體設備', '設備廠'],
    '先進封裝': ['CoWoS', '先進封裝', 'CoPoS', '玻璃基板'],
    '矽光子': ['矽光子', 'CPO'],
    '機器人': ['機器人', '人形機器人'],
    '散熱': ['散熱', '液冷', '水冷'],
    'PCB': ['PCB', '載板', 'CCL', '銅箔基板'],
    '被動元件': ['被動元件', 'MLCC'],
    '重電': ['重電', '變壓器', '電網'],
    '軍工': ['軍工', '無人機', '國防'],
    '低軌衛星': ['低軌衛星', '衛星'],
    '電動車': ['電動車', 'EV'],
    '光通訊': ['光通訊', '光收發'],
    '網通': ['網通', '交換器', '伺服器代工'],
    '面板': ['面板', 'OLED'],
    '航運': ['航運', '貨櫃', '散裝'],
    '金融': ['金控', '壽險', '銀行股'],
    '生技': ['生技', '新藥', '疫苗'],
    '綠能': ['綠能', '風電', '太陽能', '儲能'],
    '蘋概': ['蘋果概念', '蘋概', 'iPhone'],
    '高股息': ['高股息', '存股', '殖利率'],
    '觀光': ['觀光', '飯店', '旅遊'],
    '營建': ['營建', '房市', '建案'],
    '量子': ['量子', '量子電腦'],
  };
}
```

- [ ] **Step 4: 寫 StockNameMatcher 實作**

```dart
// lib/domain/services/news/stock_name_matcher.dart
import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 從新聞標題匹配公司簡稱 → 股票代碼（純函數）
///
/// 規則（依語料實證設計，見 spec）：
/// - 名稱長度 ≥ 3：全部納入；長度 = 2：僅 [NewsHeatParams.twoCharNameWhitelist]
/// - 最長優先＋位置消耗：「長榮航」命中後佔用字元，「長榮」不重複計分
/// - 同篇多次出現計 1（回傳 Set）
///
/// ⚠️ 匹配結果僅供熱度分析與快照，**不得寫入 news_stock_map**（不進評分）。
class StockNameMatcher {
  StockNameMatcher._(this._entries);

  /// (名稱, 代碼)，已按名稱長度降冪排序
  final List<(String, String)> _entries;

  factory StockNameMatcher.fromStocks(List<StockMasterEntry> stocks) {
    final entries = <(String, String)>[];
    for (final s in stocks) {
      final name = s.name.trim();
      if (name.length >= 3 ||
          (name.length == 2 &&
              NewsHeatParams.twoCharNameWhitelist.contains(name))) {
        entries.add((name, s.symbol));
      }
    }
    entries.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return StockNameMatcher._(entries);
  }

  /// 回傳標題中提及的股票代碼集合
  Set<String> match(String title) {
    final claimed = List<bool>.filled(title.length, false);
    final result = <String>{};
    for (final (name, symbol) in _entries) {
      var from = 0;
      while (true) {
        final idx = title.indexOf(name, from);
        if (idx < 0) break;
        var free = true;
        for (var i = idx; i < idx + name.length; i++) {
          if (claimed[i]) {
            free = false;
            break;
          }
        }
        if (free) {
          for (var i = idx; i < idx + name.length; i++) {
            claimed[i] = true;
          }
          result.add(symbol);
        }
        from = idx + 1;
      }
    }
    return result;
  }
}
```

- [ ] **Step 5: 跑測試確認綠**

Run: `flutter test test/domain/services/news/stock_name_matcher_test.dart`
Expected: PASS（9 tests）

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/news_heat_params.dart lib/domain/services/news/stock_name_matcher.dart test/domain/services/news/stock_name_matcher_test.dart
git commit -m "feat(news-heat): StockNameMatcher 公司名匹配引擎（最長優先＋2字白名單）"
```

---

### Task 2: 語料重放稽核（白名單定稿閘）

**Files:**
- Create: `tool/audit_name_matcher.dart`（稽核後刪除，不 commit）

**Interfaces:**
- Consumes: `StockNameMatcher.fromStocks` / `.match`（Task 1）
- Produces: 定稿後的 `NewsHeatParams.twoCharNameWhitelist`（直接修改 Task 1 的常數檔）

- [ ] **Step 1: 寫稽核腳本**

```dart
// tool/audit_name_matcher.dart
// 對 production DB 全庫標題重放 matcher，輸出 per-name 命中統計與樣本供人工抽驗。
// 用法：dart run tool/audit_name_matcher.dart <sqlite 路徑>
import 'dart:io';

import 'package:drift/native.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';

Future<void> main(List<String> args) async {
  final db = AppDatabase.forTesting(NativeDatabase(File(args.first)));
  final stocks = await db.getAllActiveStocks();
  final symbolToName = {for (final s in stocks) s.symbol: s.name};
  final matcher = StockNameMatcher.fromStocks(stocks);
  final titles = await db
      .customSelect('SELECT title FROM news_item')
      .map((r) => r.read<String>('title'))
      .get();

  final hitTitles = <String, List<String>>{};
  for (final t in titles) {
    for (final sym in matcher.match(t)) {
      hitTitles.putIfAbsent(sym, () => []).add(t);
    }
  }
  final sorted = hitTitles.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in sorted) {
    final name = symbolToName[e.key];
    stdout.writeln('${e.key} $name: ${e.value.length} 次');
    for (final t in e.value.take(3)) {
      stdout.writeln('    $t');
    }
  }
  await db.close();
}
```

（若 `AppDatabase` 無 `forTesting` 建構子，改用專案既有的 tool 連線模式——
先 `grep -rn "NativeDatabase" tool/ test/` 找現行寫法照抄。）

- [ ] **Step 2: 對 production DB 副本執行**

```bash
sqlite3 ~/Library/Containers/com.neo.afterclose/Data/Documents/afterclose.sqlite \
  "VACUUM INTO '/tmp/afterclose_audit.sqlite'"
dart run tool/audit_name_matcher.dart /tmp/afterclose_audit.sqlite > /tmp/name_audit.txt
head -200 /tmp/name_audit.txt
```

Expected: 每檔命中股票的次數＋3 筆樣本標題。

- [ ] **Step 3: 人工抽驗與白名單定稿**

- 逐一檢視 2 字白名單每個名字的樣本標題：樣本中出現**非該公司語意**
  （地名／人名／普通詞／外國公司）即從 `twoCharNameWhitelist` 移除。
- 檢視 3 字名 Top 30：確認無系統性誤配（預期近零，語料驗證過）。
- 把「總命中數、移除了哪些名字與原因」記錄到 Step 5 的 commit message。

- [ ] **Step 4: 重跑 Task 1 測試 + 全套**

Run: `flutter test test/domain/services/news/stock_name_matcher_test.dart && flutter test`
Expected: 全綠（若白名單移除的名字被測試引用，同步修 fixture）

- [ ] **Step 5: 刪腳本、commit 白名單定稿**

```bash
rm tool/audit_name_matcher.dart /tmp/afterclose_audit.sqlite /tmp/name_audit.txt
git add lib/core/constants/news_heat_params.dart test/domain/services/news/stock_name_matcher_test.dart
git commit -m "feat(news-heat): 2 字白名單語料稽核定稿（移除 N 個誤配名，總命中 M 次抽驗通過）"
```

---

### Task 3: ThemeMatcher（題材匹配，純函數）

**Files:**
- Create: `lib/domain/services/news/theme_matcher.dart`
- Test: `test/domain/services/news/theme_matcher_test.dart`

**Interfaces:**
- Consumes: `NewsHeatParams.themes`
- Produces: `ThemeMatcher().match(String title): Set<String>`（回題材名集合）

- [ ] **Step 1: 寫失敗測試**

```dart
// test/domain/services/news/theme_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/news/theme_matcher.dart';

void main() {
  final matcher = ThemeMatcher();

  test('中文題材詞命中', () {
    expect(matcher.match('記憶體漲價 南亞科受惠'), contains('記憶體'));
  });

  test('同義詞命中同一題材', () {
    expect(matcher.match('HBM 需求爆發'), contains('記憶體'));
    expect(matcher.match('CoWoS 產能滿載'), contains('先進封裝'));
  });

  test('英文詞不分大小寫', () {
    expect(matcher.match('ai 伺服器需求強勁'), contains('AI'));
    expect(matcher.match('AI晶片大單'), contains('AI'));
  });

  test('一篇可命中多題材', () {
    final r = matcher.match('AI 帶動記憶體與散熱需求');
    expect(r, containsAll(['AI', '記憶體', '散熱']));
  });

  test('無命中回空集合', () {
    expect(matcher.match('台股大盤震盪'), isEmpty);
  });
}
```

- [ ] **Step 2: 跑測試確認紅**

Run: `flutter test test/domain/services/news/theme_matcher_test.dart`
Expected: FAIL（class 不存在）

- [ ] **Step 3: 實作**

```dart
// lib/domain/services/news/theme_matcher.dart
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
```

- [ ] **Step 4: 跑測試確認綠**

Run: `flutter test test/domain/services/news/theme_matcher_test.dart`
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/news/theme_matcher.dart test/domain/services/news/theme_matcher_test.dart
git commit -m "feat(news-heat): ThemeMatcher 題材匹配（同義詞組、英文不分大小寫）"
```

---

### Task 4: HeatCalculator（熱度計算，純函數）

**Files:**
- Create: `lib/domain/services/news/heat_calculator.dart`
- Test: `test/domain/services/news/heat_calculator_test.dart`

**Interfaces:**
- Consumes: 無（純資料輸入）
- Produces:
  - `ArticleTags({required String newsId, required DateTime publishedAt, required Set<String> symbols, required Set<String> themes})`
  - `StockHeat`（欄位 `symbol`, `mentions7d`, `mentionsPrev21d`, `isSurging`）
  - `ThemeHeat`（欄位 `theme`, `articles7d`, `articlesPrev21d`, `isSurging`, `topStocks: List<String>`）
  - `HeatResult`（欄位 `stocks: List<StockHeat>`（mentions7d 降冪）, `themes: List<ThemeHeat>`（articles7d 降冪））
  - `HeatCalculator.compute(List<ArticleTags> articles, {required DateTime now}): HeatResult`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/domain/services/news/heat_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/news/heat_calculator.dart';

ArticleTags article(
  String id,
  DateTime publishedAt, {
  Set<String> symbols = const {},
  Set<String> themes = const {},
}) => ArticleTags(
  newsId: id,
  publishedAt: publishedAt,
  symbols: symbols,
  themes: themes,
);

void main() {
  final now = DateTime(2026, 7, 15, 20, 0);
  final calc = HeatCalculator();

  test('近 7 天與前 21 天窗口切分（含當天）', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 15, 9), symbols: {'2330'}), // day 0 → 近窗
      article('b', DateTime(2026, 7, 9, 9), symbols: {'2330'}), // day 6 → 近窗
      article('c', DateTime(2026, 7, 8, 9), symbols: {'2330'}), // day 7 → 基準窗
      article('d', DateTime(2026, 6, 18, 9), symbols: {'2330'}), // day 27 → 基準窗
      article('e', DateTime(2026, 6, 16, 9), symbols: {'2330'}), // day 29 → 忽略
    ], now: now);
    final heat = r.stocks.single;
    expect(heat.mentions7d, 2);
    expect(heat.mentionsPrev21d, 2);
  });

  test('爆量：近 7 天 >= 前 21 天總數且 >= 3 篇', () {
    List<ArticleTags> mentions(int recent, int baseline) => [
      for (var i = 0; i < recent; i++)
        article('r$i', DateTime(2026, 7, 14, 9), symbols: {'3231'}),
      for (var i = 0; i < baseline; i++)
        article('b$i', DateTime(2026, 7, 1, 9), symbols: {'3231'}),
    ];
    expect(
      calc.compute(mentions(3, 3), now: now).stocks.single.isSurging,
      isTrue,
    );
    expect(
      calc.compute(mentions(2, 0), now: now).stocks.single.isSurging,
      isFalse, // 低基數：未達 3 篇
    );
    expect(
      calc.compute(mentions(3, 4), now: now).stocks.single.isSurging,
      isFalse, // 3 < 4
    );
  });

  test('焦點股按 mentions7d 降冪排序', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 14, 9), symbols: {'2330', '2317'}),
      article('b', DateTime(2026, 7, 14, 10), symbols: {'2330'}),
    ], now: now);
    expect(r.stocks.map((s) => s.symbol).toList(), ['2330', '2317']);
  });

  test('題材熱度與成分股（近 7 天共現次數 Top N）', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 14, 9),
          themes: {'記憶體'}, symbols: {'2408'}),
      article('b', DateTime(2026, 7, 14, 10),
          themes: {'記憶體'}, symbols: {'2408', '2344'}),
      article('c', DateTime(2026, 7, 1, 9), themes: {'記憶體'}),
    ], now: now);
    final theme = r.themes.single;
    expect(theme.articles7d, 2);
    expect(theme.articlesPrev21d, 1);
    expect(theme.topStocks.first, '2408'); // 共現 2 次 > 2344 的 1 次
  });

  test('空輸入回空結果', () {
    final r = calc.compute([], now: now);
    expect(r.stocks, isEmpty);
    expect(r.themes, isEmpty);
  });
}
```

- [ ] **Step 2: 跑測試確認紅**

Run: `flutter test test/domain/services/news/heat_calculator_test.dart`
Expected: FAIL（class 不存在）

- [ ] **Step 3: 實作**

```dart
// lib/domain/services/news/heat_calculator.dart
import 'package:afterclose/core/constants/news_heat_params.dart';

/// 一篇新聞的標籤（matcher 輸出的彙整）
class ArticleTags {
  const ArticleTags({
    required this.newsId,
    required this.publishedAt,
    required this.symbols,
    required this.themes,
  });

  final String newsId;
  final DateTime publishedAt;
  final Set<String> symbols;
  final Set<String> themes;
}

/// 焦點股熱度
class StockHeat {
  const StockHeat({
    required this.symbol,
    required this.mentions7d,
    required this.mentionsPrev21d,
    required this.isSurging,
  });

  final String symbol;
  final int mentions7d;
  final int mentionsPrev21d;
  final bool isSurging;
}

/// 題材熱度
class ThemeHeat {
  const ThemeHeat({
    required this.theme,
    required this.articles7d,
    required this.articlesPrev21d,
    required this.isSurging,
    required this.topStocks,
  });

  final String theme;
  final int articles7d;
  final int articlesPrev21d;
  final bool isSurging;

  /// 近 7 天與該題材共現次數最高的個股（Top [NewsHeatParams.themeTopStocksCount]）
  final List<String> topStocks;
}

class HeatResult {
  const HeatResult({required this.stocks, required this.themes});

  /// mentions7d 降冪
  final List<StockHeat> stocks;

  /// articles7d 降冪
  final List<ThemeHeat> themes;
}

/// 熱度計算（純函數）：窗口切分與爆量判定
///
/// 窗口以 **local 日曆日差**切分：0–6 天＝近窗、7–27 天＝基準窗、其餘忽略。
/// 爆量＝近 7 天篇數達前 21 天週均 3 倍（等價 `mentions7d >= mentionsPrev21d`）
/// 且 `mentions7d >= surgeMinMentions`。
class HeatCalculator {
  HeatResult compute(List<ArticleTags> articles, {required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    final stockRecent = <String, int>{};
    final stockBaseline = <String, int>{};
    final themeRecent = <String, int>{};
    final themeBaseline = <String, int>{};
    // (theme, symbol) 近窗共現次數
    final coOccurrence = <String, Map<String, int>>{};

    for (final a in articles) {
      final local = a.publishedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      final isRecent = diff >= 0 && diff < NewsHeatParams.recentWindowDays;
      final isBaseline =
          diff >= NewsHeatParams.recentWindowDays &&
          diff <
              NewsHeatParams.recentWindowDays +
                  NewsHeatParams.baselineWindowDays;
      if (!isRecent && !isBaseline) continue;

      final stockBucket = isRecent ? stockRecent : stockBaseline;
      for (final s in a.symbols) {
        stockBucket[s] = (stockBucket[s] ?? 0) + 1;
      }
      final themeBucket = isRecent ? themeRecent : themeBaseline;
      for (final t in a.themes) {
        themeBucket[t] = (themeBucket[t] ?? 0) + 1;
        if (isRecent) {
          final co = coOccurrence.putIfAbsent(t, () => {});
          for (final s in a.symbols) {
            co[s] = (co[s] ?? 0) + 1;
          }
        }
      }
    }

    bool surging(int recent, int baseline) =>
        recent >= NewsHeatParams.surgeMinMentions && recent >= baseline;

    final stocks =
        {...stockRecent.keys, ...stockBaseline.keys}.map((s) {
            final r = stockRecent[s] ?? 0;
            final b = stockBaseline[s] ?? 0;
            return StockHeat(
              symbol: s,
              mentions7d: r,
              mentionsPrev21d: b,
              isSurging: surging(r, b),
            );
          }).toList()
          ..sort((a, b) {
            final byRecent = b.mentions7d.compareTo(a.mentions7d);
            if (byRecent != 0) return byRecent;
            return a.symbol.compareTo(b.symbol);
          });

    final themes =
        {...themeRecent.keys, ...themeBaseline.keys}.map((t) {
            final r = themeRecent[t] ?? 0;
            final b = themeBaseline[t] ?? 0;
            final co = coOccurrence[t] ?? const <String, int>{};
            final top = co.entries.toList()
              ..sort((x, y) {
                final byCount = y.value.compareTo(x.value);
                if (byCount != 0) return byCount;
                return x.key.compareTo(y.key);
              });
            return ThemeHeat(
              theme: t,
              articles7d: r,
              articlesPrev21d: b,
              isSurging: surging(r, b),
              topStocks: top
                  .take(NewsHeatParams.themeTopStocksCount)
                  .map((e) => e.key)
                  .toList(),
            );
          }).toList()
          ..sort((a, b) {
            final byRecent = b.articles7d.compareTo(a.articles7d);
            if (byRecent != 0) return byRecent;
            return a.theme.compareTo(b.theme);
          });

    return HeatResult(stocks: stocks, themes: themes);
  }
}
```

- [ ] **Step 4: 跑測試確認綠**

Run: `flutter test test/domain/services/news/heat_calculator_test.dart`
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/news/heat_calculator.dart test/domain/services/news/heat_calculator_test.dart
git commit -m "feat(news-heat): HeatCalculator 窗口切分與爆量判定"
```

---

### Task 5: `news_mention_daily` 快照表 + DAO

**Files:**
- Modify: `lib/data/database/tables/news_tables.dart`（加表）
- Modify: `lib/data/database/app_database.dart`（註冊表、bump `_schemaFingerprint`、`_userInputTableNames` 加 `news_mention_daily`）
- Modify: `lib/data/database/dao/news_dao.dart`（加 upsert／查詢方法；若專案把 news 相關 DAO 放別檔，`grep -rn "getNewsStockMappingsBatch" lib/data/database/` 找到正確檔案照該處慣例加）
- Test: `test/data/database/dao/news_mention_daily_dao_test.dart`

**Interfaces:**
- Consumes: drift 既有基礎設施
- Produces:
  - Table `NewsMentionDaily`：`date DateTime`, `kind Text`（'stock'|'theme'）, `itemKey Text`, `mentionCount int`, `dictionaryVersion int`，PK (date, kind, itemKey)
  - DAO：`Future<void> upsertMentionCounts(List<NewsMentionDailyCompanion> rows)`（batch insertOrReplace）
  - DAO：`Future<List<NewsMentionDailyEntry>> getMentionCounts({required DateTime from})`

- [ ] **Step 1: 加表定義**

```dart
// 追加到 lib/data/database/tables/news_tables.dart 末尾
/// 每日提及數快照（新聞熱度發現層）
///
/// 唯一消費者是**未來回測**（顯示層即時計算、不讀此表）。
/// 新聞 30 天清理後提及數不可回補，故此表：
/// 1. 必須列入 app_database 的 `_userInputTableNames`（fingerprint reset 不得 wipe）
/// 2. 帶 dictionaryVersion 供回測取同版本區段（字典演化防假爆量）
@DataClassName('NewsMentionDailyEntry')
@TableIndex(name: 'idx_news_mention_daily_date', columns: {#date})
class NewsMentionDaily extends Table {
  /// 本地日曆日（新聞 publishedAt 的 local 日）
  DateTimeColumn get date => dateTime()();

  /// 'stock' 或 'theme'
  TextColumn get kind => text()();

  /// symbol（kind=stock）或題材名（kind=theme）
  TextColumn get itemKey => text()();

  /// 該日提及篇數
  IntColumn get mentionCount => integer()();

  /// 寫入當下的 NewsHeatParams.dictionaryVersion
  IntColumn get dictionaryVersion => integer()();

  @override
  Set<Column> get primaryKey => {date, kind, itemKey};
}
```

- [ ] **Step 2: 註冊表 + fingerprint + whitelist**

在 `lib/data/database/app_database.dart`：
1. `@DriftDatabase(tables: [...])` 清單加 `NewsMentionDaily`
2. `_schemaFingerprint` 字串 bump 為 `'<現值前綴>-news-mention-daily-2026-07-15'`（沿用檔內既有格式）
3. `_userInputTableNames` 加 `'news_mention_daily', // 熱度快照：歷史不可重建，fingerprint reset 不得 wipe`

- [ ] **Step 3: 跑 code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功生成，無 conflict。

- [ ] **Step 4: 寫失敗 DAO 測試**

```dart
// test/data/database/dao/news_mention_daily_dao_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  NewsMentionDailyCompanion row(
    DateTime date,
    String kind,
    String key,
    int count,
  ) => NewsMentionDailyCompanion.insert(
    date: date,
    kind: kind,
    itemKey: key,
    mentionCount: count,
    dictionaryVersion: 1,
  );

  test('upsert 寫入與讀回', () async {
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 15), 'stock', '2330', 5),
      row(DateTime(2026, 7, 15), 'theme', '記憶體', 8),
    ]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 1));
    expect(rows, hasLength(2));
  });

  test('同 (date,kind,key) 重寫覆蓋（冪等回補）', () async {
    await db.upsertMentionCounts([row(DateTime(2026, 7, 15), 'stock', '2330', 3)]);
    await db.upsertMentionCounts([row(DateTime(2026, 7, 15), 'stock', '2330', 7)]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 1));
    expect(rows.single.mentionCount, 7);
  });

  test('from 過濾', () async {
    await db.upsertMentionCounts([
      row(DateTime(2026, 7, 1), 'stock', '2330', 1),
      row(DateTime(2026, 7, 15), 'stock', '2330', 2),
    ]);
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 10));
    expect(rows.single.mentionCount, 2);
  });
}
```

（`AppDatabase.forTesting` 若不存在，`grep -rn "NativeDatabase.memory" test/` 找專案既有 in-memory 建構慣例照抄。）

- [ ] **Step 5: 跑測試確認紅**

Run: `flutter test test/data/database/dao/news_mention_daily_dao_test.dart`
Expected: FAIL（DAO 方法不存在）

- [ ] **Step 6: 實作 DAO 方法**

加到 news DAO 所在檔（照 Step 4 前的 grep 結果；方法掛在既有 news DAO mixin/class）：

```dart
/// 快照 upsert（(date,kind,itemKey) 覆蓋——供每日回補冪等重寫）
Future<void> upsertMentionCounts(List<NewsMentionDailyCompanion> rows) async {
  if (rows.isEmpty) return;
  await batch((b) {
    for (final r in rows) {
      b.insert(newsMentionDaily, r, mode: InsertMode.insertOrReplace);
    }
  });
}

/// 讀取快照（date >= from），未來回測用；測試亦用此驗證寫入
Future<List<NewsMentionDailyEntry>> getMentionCounts({
  required DateTime from,
}) {
  return (select(newsMentionDaily)
        ..where((t) => t.date.isBiggerOrEqualValue(from))
        ..orderBy([(t) => OrderingTerm.asc(t.date)]))
      .get();
}
```

- [ ] **Step 7: 跑測試確認綠 + 全套**

Run: `flutter test test/data/database/dao/news_mention_daily_dao_test.dart && flutter test`
Expected: 全綠（fingerprint bump 會使既有本機 DB 於下次啟動 reset 非白名單表——derived data 重抓即可，屬已知機制）

- [ ] **Step 8: Commit**

```bash
git add lib/data/database/ test/data/database/dao/news_mention_daily_dao_test.dart
git commit -m "feat(news-heat): news_mention_daily 快照表（PK date+kind+itemKey、列入 wipe 白名單）"
```

---

### Task 6: NewsMentionSnapshotService + UpdateService fail-safe 整合

**Files:**
- Create: `lib/domain/services/update/news_mention_snapshot_service.dart`
- Modify: `lib/domain/services/update_service.dart`（尾端掛載，仿 `_updateRuleAccuracyStatsFailSafe` at `update_service.dart:844`）
- Modify: `lib/domain/services/update_service_deps.dart` 與 `update_service_factory.dart`（依既有 services 注入模式加欄位；先讀這兩檔照現行慣例）
- Test: `test/domain/services/update/news_mention_snapshot_service_test.dart`

**Interfaces:**
- Consumes: `StockNameMatcher`（Task 1）、`ThemeMatcher`（Task 3）、`db.getAllActiveStocks()`、`NewsRepository.getRecentNews({int days})`、DAO `upsertMentionCounts`（Task 5）
- Produces: `NewsMentionSnapshotService({required AppDatabase database, required INewsRepository newsRepository, AppClock clock}).snapshotRecentDays(): Future<void>`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/domain/services/update/news_mention_snapshot_service_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:afterclose/domain/services/update/news_mention_snapshot_service.dart';

class MockNewsRepository extends Mock implements INewsRepository {}

class _FixedClock implements AppClock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

NewsItemEntry news(String id, String title, DateTime publishedAt) =>
    NewsItemEntry(
      id: id,
      source: '鉅亨網',
      title: title,
      url: 'https://example.com/$id',
      category: 'OTHER',
      publishedAt: publishedAt,
      fetchedAt: publishedAt,
    );

void main() {
  late AppDatabase db;
  late MockNewsRepository newsRepo;
  late NewsMentionSnapshotService service;
  final now = DateTime(2026, 7, 15, 20, 0);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 匹配字典需要 stock_master
    await db.batch((b) {
      b.insertAll(db.stockMaster, [
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
      ]);
    });
    newsRepo = MockNewsRepository();
    service = NewsMentionSnapshotService(
      database: db,
      newsRepository: newsRepo,
      clock: _FixedClock(now),
    );
  });

  tearDown(() async => db.close());

  test('近 3 日提及數落地（stock 與 theme）', () async {
    when(() => newsRepo.getRecentNews(days: any(named: 'days'))).thenAnswer(
      (_) async => [
        news('a', '台積電法說 AI 需求強', DateTime(2026, 7, 15, 9)),
        news('b', '台積電再創高', DateTime(2026, 7, 14, 9)),
        news('c', '記憶體漲價', DateTime(2026, 7, 15, 10)),
      ],
    );

    await service.snapshotRecentDays();

    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 13));
    final stock715 = rows.singleWhere(
      (r) => r.kind == 'stock' && r.itemKey == '2330' && r.date.day == 15,
    );
    expect(stock715.mentionCount, 1);
    expect(stock715.dictionaryVersion, greaterThanOrEqualTo(1));
    expect(
      rows.any((r) => r.kind == 'theme' && r.itemKey == '記憶體'),
      isTrue,
    );
    expect(rows.any((r) => r.kind == 'theme' && r.itemKey == 'AI'), isTrue);
  });

  test('重跑冪等（同日重寫不重複累加）', () async {
    when(() => newsRepo.getRecentNews(days: any(named: 'days'))).thenAnswer(
      (_) async => [news('a', '台積電再創高', DateTime(2026, 7, 15, 9))],
    );
    await service.snapshotRecentDays();
    await service.snapshotRecentDays();
    final rows = await db.getMentionCounts(from: DateTime(2026, 7, 15));
    expect(
      rows.where((r) => r.kind == 'stock' && r.itemKey == '2330'),
      hasLength(1),
    );
    expect(rows.first.mentionCount, 1);
  });
}
```

- [ ] **Step 2: 跑測試確認紅**

Run: `flutter test test/domain/services/update/news_mention_snapshot_service_test.dart`
Expected: FAIL（class 不存在）

- [ ] **Step 3: 實作 service**

```dart
// lib/domain/services/update/news_mention_snapshot_service.dart
import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';
import 'package:afterclose/domain/services/news/theme_matcher.dart';
import 'package:drift/drift.dart';

/// 每日提及數快照（新聞熱度發現層）
///
/// 每次回補最近 [NewsHeatParams.snapshotBackfillDays] 個本地日
/// （重算後 upsert，晚到新聞自我修正、天然冪等）。
/// 由 UpdateService 於更新尾端 fail-safe 呼叫；顯示層不依賴此表。
class NewsMentionSnapshotService {
  NewsMentionSnapshotService({
    required AppDatabase database,
    required INewsRepository newsRepository,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _newsRepo = newsRepository,
       _clock = clock;

  final AppDatabase _db;
  final INewsRepository _newsRepo;
  final AppClock _clock;

  Future<void> snapshotRecentDays() async {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final backfillDays = NewsHeatParams.snapshotBackfillDays;

    // +1 天緩衝涵蓋時區邊界
    final news = await _newsRepo.getRecentNews(days: backfillDays + 1);
    if (news.isEmpty) return;

    final stocks = await _db.getAllActiveStocks();
    final nameMatcher = StockNameMatcher.fromStocks(stocks);
    final themeMatcher = ThemeMatcher();

    // (localDay, kind, key) → count
    final counts = <(DateTime, String, String), int>{};
    for (final n in news) {
      final local = n.publishedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      if (diff < 0 || diff >= backfillDays) continue;

      for (final sym in nameMatcher.match(n.title)) {
        final k = (day, 'stock', sym);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final theme in themeMatcher.match(n.title)) {
        final k = (day, 'theme', theme);
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return;

    await _db.upsertMentionCounts([
      for (final e in counts.entries)
        NewsMentionDailyCompanion.insert(
          date: e.key.$1,
          kind: e.key.$2,
          itemKey: e.key.$3,
          mentionCount: e.value,
          dictionaryVersion: NewsHeatParams.dictionaryVersion,
        ),
    ]);
  }
}
```

- [ ] **Step 4: 跑測試確認綠**

Run: `flutter test test/domain/services/update/news_mention_snapshot_service_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 5: UpdateService 整合（fail-safe）**

先讀 `lib/domain/services/update_service_deps.dart` 與
`lib/domain/services/update_service_factory.dart`，照 `ruleAccuracy` 的
nullable-service 注入慣例加 `newsMentionSnapshot` 欄位。然後在
`update_service.dart`：

1. 加 field：`final NewsMentionSnapshotService? _newsMentionSnapshotService;`
   （constructor 由 `services.newsMentionSnapshot` 指派）
2. 在 `_updateRuleAccuracyStatsFailSafe()` 呼叫點（`update_service.dart:292`
   附近）之後加一行 `await _snapshotNewsMentionsFailSafe();`
3. 加方法（仿 `update_service.dart:844` 的既有 fail-safe 模式）：

```dart
/// 新聞提及數快照（fail-safe：失敗只記 log，不中斷更新）
Future<void> _snapshotNewsMentionsFailSafe() async {
  final service = _newsMentionSnapshotService;
  if (service == null) return;
  try {
    await service.snapshotRecentDays();
  } catch (e) {
    AppLogger.warning('UpdateService', '新聞提及快照失敗（不影響更新）', e);
  }
}
```

- [ ] **Step 6: 寫 fail-safe 隔離測試**

在既有 `test/domain/services/update_service_test.dart`（先 grep 確認檔名）加：

```dart
test('新聞提及快照拋例外時更新流程照常完成', () async {
  // 照該測試檔既有的 UpdateService 組裝模式，把 newsMentionSnapshot 換成
  // 會 throw 的 mock：
  // when(() => mockSnapshotService.snapshotRecentDays())
  //     .thenThrow(Exception('snapshot boom'));
  // 跑完整 runDailyUpdate（其餘 syncer 均 stub 成功）
  // expect：update result 成功、無 rethrow
});
```

（測試組裝細節照該檔既有 pattern 填；斷言重點＝快照 throw 不影響
`runDailyUpdate` 的成功結果。）

- [ ] **Step 7: 全套測試**

Run: `flutter test`
Expected: 全綠

- [ ] **Step 8: Commit**

```bash
git add lib/domain/services/update/news_mention_snapshot_service.dart lib/domain/services/update_service.dart lib/domain/services/update_service_deps.dart lib/domain/services/update_service_factory.dart test/domain/services/
git commit -m "feat(news-heat): 每日提及數快照掛進更新尾端（fail-safe、3 日冪等回補）"
```

---

### Task 7: newsHeatProvider（熱度分析狀態）

**Files:**
- Create: `lib/presentation/providers/news_heat_provider.dart`
- Test: `test/presentation/providers/news_heat_provider_test.dart`

**Interfaces:**
- Consumes:
  - `newsRepositoryProvider`（`getRecentNews(days: 28)`）
  - `databaseProvider`（`getAllActiveStocks()`）
  - `modeRecommendationsProvider(ScoringMode)`（`lib/presentation/providers/mode_recommendation_provider.dart:597`，回 `List<ModeRecommendation>`，`.symbol` 欄位）
  - `dataUpdateEpochProvider`（auto-reload）
  - Task 1/3/4 的 matcher 與 calculator
- Produces:

```dart
class NewsHeatAnalysis {
  final List<ThemeHeat> themes;          // Top topThemesCount
  final List<StockHeat> stocks;          // Top topStocksCount
  final Map<String, String> stockNames;  // symbol → 名稱（顯示用）
  final Map<String, ScoringMode> modeBySymbol; // 三模式交叉（無則缺 key）
}
final newsHeatProvider = FutureProvider<NewsHeatAnalysis>(...);
```

- [ ] **Step 1: 寫失敗測試**

```dart
// test/presentation/providers/news_heat_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockNewsRepository extends Mock implements NewsRepository {}

NewsItemEntry news(String id, String title, DateTime publishedAt) =>
    NewsItemEntry(
      id: id,
      source: '鉅亨網',
      title: title,
      url: 'https://example.com/$id',
      category: 'OTHER',
      publishedAt: publishedAt,
      fetchedAt: publishedAt,
    );

StockMasterEntry stock(String symbol, String name) => StockMasterEntry(
  symbol: symbol,
  name: name,
  market: 'TWSE',
  industry: '電子工業',
  isActive: true,
  updatedAt: DateTime(2026, 7, 15),
);

ModeRecommendation rec(String symbol) => ModeRecommendation(
  symbol: symbol,
  rank: 1,
  modeScoreShort: 20,
  modeScoreLong: 20,
  reasons: const [],
);

void main() {
  late MockAppDatabase mockDb;
  late MockNewsRepository mockNewsRepo;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDatabase();
    mockNewsRepo = MockNewsRepository();
    when(() => mockDb.getAllActiveStocks()).thenAnswer(
      (_) async => [stock('2330', '台積電'), stock('2408', '南亞科')],
    );
    when(() => mockNewsRepo.getRecentNews(days: any(named: 'days'))).thenAnswer(
      (_) async => [
        news('a', '台積電法說會', DateTime.now()),
        news('b', '記憶體漲價 南亞科受惠', DateTime.now()),
        news('c', '南亞科獲利創高', DateTime.now()),
      ],
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        newsRepositoryProvider.overrideWithValue(mockNewsRepo),
        // 三模式：南亞科在回檔（weaknessObserve）
        for (final m in ScoringMode.userFacingModes)
          modeRecommendationsProvider(m).overrideWith(
            (ref) async =>
                m == ScoringMode.weaknessObserve ? [rec('2408')] : [],
          ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('焦點股按提及數排序並帶名稱', () async {
    final r = await container.read(newsHeatProvider.future);
    expect(r.stocks.first.symbol, '2408'); // 2 篇 > 台積電 1 篇
    expect(r.stockNames['2408'], '南亞科');
  });

  test('題材熱度與成分股', () async {
    final r = await container.read(newsHeatProvider.future);
    final memory = r.themes.firstWhere((t) => t.theme == '記憶體');
    expect(memory.articles7d, 1);
    expect(memory.topStocks, contains('2408'));
  });

  test('三模式交叉：回檔股標注 weaknessObserve', () async {
    final r = await container.read(newsHeatProvider.future);
    expect(r.modeBySymbol['2408'], ScoringMode.weaknessObserve);
    expect(r.modeBySymbol.containsKey('2330'), isFalse);
  });
}
```

- [ ] **Step 2: 跑測試確認紅**

Run: `flutter test test/presentation/providers/news_heat_provider_test.dart`
Expected: FAIL（provider 不存在）

- [ ] **Step 3: 實作 provider**

```dart
// lib/presentation/providers/news_heat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/domain/services/news/heat_calculator.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';
import 'package:afterclose/domain/services/news/theme_matcher.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 熱度分析結果（新聞頁「熱度分析」Tab 的完整狀態）
class NewsHeatAnalysis {
  const NewsHeatAnalysis({
    required this.themes,
    required this.stocks,
    required this.stockNames,
    required this.modeBySymbol,
  });

  /// 主流族群 Top N（articles7d 降冪）
  final List<ThemeHeat> themes;

  /// 焦點股 Top N（mentions7d 降冪）
  final List<StockHeat> stocks;

  /// symbol → 公司名（顯示用）
  final Map<String, String> stockNames;

  /// 三模式交叉：symbol → 當前指派 mode（未入選任何 mode 則缺 key）
  final Map<String, ScoringMode> modeBySymbol;
}

/// 即時計算近 28 天新聞的熱度分析。
///
/// 資料源與新聞頁共用（重新整理抓完 RSS 後 invalidate 本 provider 即同步）。
/// 匹配結果只存在記憶體，不寫 news_stock_map（不進評分）。
final newsHeatProvider = FutureProvider<NewsHeatAnalysis>((ref) async {
  ref.watch(dataUpdateEpochProvider);

  final newsRepo = ref.read(newsRepositoryProvider);
  final db = ref.read(databaseProvider);

  final windowDays =
      NewsHeatParams.recentWindowDays + NewsHeatParams.baselineWindowDays;
  final news = await newsRepo.getRecentNews(days: windowDays);
  final stocks = await db.getAllActiveStocks();

  final nameMatcher = StockNameMatcher.fromStocks(stocks);
  final themeMatcher = ThemeMatcher();
  final articles = [
    for (final n in news)
      ArticleTags(
        newsId: n.id,
        publishedAt: n.publishedAt,
        symbols: nameMatcher.match(n.title),
        themes: themeMatcher.match(n.title),
      ),
  ];
  final heat = HeatCalculator().compute(articles, now: DateTime.now());

  // 三模式交叉（與今日頁同源）
  final modeBySymbol = <String, ScoringMode>{};
  for (final mode in ScoringMode.userFacingModes) {
    final recs = await ref.watch(modeRecommendationsProvider(mode).future);
    for (final r in recs) {
      modeBySymbol[r.symbol] = mode;
    }
  }

  return NewsHeatAnalysis(
    themes: heat.themes.take(NewsHeatParams.topThemesCount).toList(),
    stocks: heat.stocks.take(NewsHeatParams.topStocksCount).toList(),
    stockNames: {for (final s in stocks) s.symbol: s.name},
    modeBySymbol: modeBySymbol,
  );
});
```

- [ ] **Step 4: 跑測試確認綠**

Run: `flutter test test/presentation/providers/news_heat_provider_test.dart`
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/news_heat_provider.dart test/presentation/providers/news_heat_provider_test.dart
git commit -m "feat(news-heat): newsHeatProvider 即時熱度分析（含三模式交叉）"
```

---

### Task 8: UI — 新聞頁「熱度分析」Tab

**Files:**
- Modify: `lib/presentation/screens/news/news_screen.dart`（AppBar 加 TabBar：全部新聞｜熱度分析；既有 body 抽成 `_AllNewsTab`）
- Create: `lib/presentation/screens/news/heat_analysis_tab.dart`
- Modify: `assets/translations/en.json`、`assets/translations/zh-TW.json`（新 key）
- Test: `test/presentation/screens/news/heat_analysis_tab_test.dart`

**Interfaces:**
- Consumes: `newsHeatProvider`（Task 7 的 `NewsHeatAnalysis`）、`ScoringMode`、`AppRoutes`（個股詳情路由——先 grep `AppRoutes` 找 stock detail 路由常數與 push 慣例照抄）
- Produces: 使用者可見的熱度分析分頁

- [ ] **Step 1: i18n key**

`zh-TW.json`（`news` 或對應區塊，照檔內結構）：

```json
"heatTab": "熱度分析",
"allNewsTab": "全部新聞",
"hotThemes": "主流族群",
"focusStocks": "焦點股",
"surgeBadge": "爆量",
"pullbackOnly": "只看回檔中",
"articlesCount": "{} 篇",
"prevWeekCount": "前三週共 {} 篇",
"heatEmpty": "近期新聞不足，無法分析熱度"
```

`en.json` 對應英文值（`"heatTab": "Heat"` 等，逐 key 對稱）。

- [ ] **Step 2: 寫失敗 widget 測試**

```dart
// test/presentation/screens/news/heat_analysis_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/domain/services/news/heat_calculator.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';
import 'package:afterclose/presentation/screens/news/heat_analysis_tab.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

NewsHeatAnalysis analysis() => NewsHeatAnalysis(
  themes: const [
    ThemeHeat(
      theme: '記憶體',
      articles7d: 23,
      articlesPrev21d: 6,
      isSurging: true,
      topStocks: ['2408', '2344'],
    ),
  ],
  stocks: const [
    StockHeat(
      symbol: '2408',
      mentions7d: 9,
      mentionsPrev21d: 2,
      isSurging: true,
    ),
    StockHeat(
      symbol: '2330',
      mentions7d: 30,
      mentionsPrev21d: 40,
      isSurging: false,
    ),
  ],
  stockNames: const {'2408': '南亞科', '2344': '華邦電', '2330': '台積電'},
  modeBySymbol: const {'2408': ScoringMode.weaknessObserve},
);

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget build(NewsHeatAnalysis data) => buildProviderTestApp(
    const HeatAnalysisTab(),
    overrides: [
      newsHeatProvider.overrideWith((ref) async => data),
    ],
  );

  testWidgets('顯示主流族群卡片與成分股', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    expect(find.text('記憶體'), findsOneWidget);
    expect(find.text('南亞科'), findsWidgets);
  });

  testWidgets('焦點股列表含爆量徽章與回檔標注', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    expect(find.text('台積電'), findsOneWidget);
    // 爆量徽章（2408）至少一個
    expect(find.text('爆量'), findsWidgets);
    // 回檔標注（ScoringMode.weaknessObserve.label 的實際字串，照 enum 取）
    expect(find.textContaining('回檔'), findsWidgets);
  });

  testWidgets('只看回檔中過濾', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('只看回檔中'));
    await tester.pumpAndSettle();

    expect(find.text('南亞科'), findsWidgets);
    expect(find.text('台積電'), findsNothing);
  });

  testWidgets('空資料顯示空狀態', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(const NewsHeatAnalysis(
      themes: [],
      stocks: [],
      stockNames: {},
      modeBySymbol: {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('近期新聞不足，無法分析熱度'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 跑測試確認紅**

Run: `flutter test test/presentation/screens/news/heat_analysis_tab_test.dart`
Expected: FAIL（`HeatAnalysisTab` 不存在）

- [ ] **Step 4: 實作 HeatAnalysisTab**

```dart
// lib/presentation/screens/news/heat_analysis_tab.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';

/// 新聞頁「熱度分析」分頁：主流族群 + 焦點股（三模式交叉）
class HeatAnalysisTab extends ConsumerStatefulWidget {
  const HeatAnalysisTab({super.key});

  @override
  ConsumerState<HeatAnalysisTab> createState() => _HeatAnalysisTabState();
}

class _HeatAnalysisTabState extends ConsumerState<HeatAnalysisTab> {
  bool _pullbackOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(newsHeatProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (data) {
        if (data.themes.isEmpty && data.stocks.isEmpty) {
          return Center(child: Text('news.heatEmpty'.tr()));
        }
        final stocks = _pullbackOnly
            ? data.stocks
                  .where(
                    (s) =>
                        data.modeBySymbol[s.symbol] ==
                        ScoringMode.weaknessObserve,
                  )
                  .toList()
            : data.stocks;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(newsHeatProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'news.hotThemes'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final t in data.themes)
                _ThemeCard(theme: t, stockNames: data.stockNames),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'news.focusStocks'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  FilterChip(
                    label: Text('news.pullbackOnly'.tr()),
                    selected: _pullbackOnly,
                    onSelected: (v) => setState(() => _pullbackOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final s in stocks)
                _FocusStockTile(
                  heat: s,
                  name: data.stockNames[s.symbol],
                  mode: data.modeBySymbol[s.symbol],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.stockNames});

  final ThemeHeat theme;
  final Map<String, String> stockNames;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  theme.theme,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                if (theme.isSurging) _SurgeBadge(),
                const Spacer(),
                Text(
                  'news.articlesCount'.tr(args: ['${theme.articles7d}']),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'news.prevWeekCount'.tr(args: ['${theme.articlesPrev21d}']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final sym in theme.topStocks)
                  ActionChip(
                    label: Text(stockNames[sym] ?? sym),
                    onPressed: () => _openStockDetail(context, sym),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusStockTile extends StatelessWidget {
  const _FocusStockTile({required this.heat, this.name, this.mode});

  final StockHeat heat;
  final String? name;
  final ScoringMode? mode;

  @override
  Widget build(BuildContext context) {
    final isPullback = mode == ScoringMode.weaknessObserve;
    return Card(
      color: isPullback
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .3)
          : null,
      child: ListTile(
        title: Row(
          children: [
            Text(name ?? heat.symbol),
            const SizedBox(width: 6),
            Text(
              heat.symbol,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            if (heat.isSurging) _SurgeBadge(),
            if (mode != null) ...[
              const SizedBox(width: 6),
              _ModeBadge(mode: mode!),
            ],
          ],
        ),
        subtitle: Text(
          '${'news.articlesCount'.tr(args: ['${heat.mentions7d}'])} · '
          '${'news.prevWeekCount'.tr(args: ['${heat.mentionsPrev21d}'])}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openStockDetail(context, heat.symbol),
      ),
    );
  }
}

class _SurgeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'news.surgeBadge'.tr(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final ScoringMode mode;

  @override
  Widget build(BuildContext context) {
    // ScoringMode 的顯示字串：先 grep lib/core/constants/scoring_mode.dart
    // 找既有 label/displayName getter 照用；沒有則就地 switch 出「起漲/強勢/回檔」
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        switch (mode) {
          ScoringMode.momentumEntry => '起漲',
          ScoringMode.strengthObserve => '強勢',
          ScoringMode.weaknessObserve => '回檔',
          ScoringMode.neutral => '',
        },
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

void _openStockDetail(BuildContext context, String symbol) {
  // 照專案既有個股詳情導航慣例：grep -rn "stockDetail" lib/presentation
  // 找 AppRoutes 常數與 push 寫法照抄（禁止硬編碼路由字串）。
}
```

（`_openStockDetail` 與 `_ModeBadge` 標注處：實作時先 grep 既有慣例填入
真實導航呼叫與 mode 顯示字串——**不得留空實作進 commit**。）

- [ ] **Step 5: news_screen 加 TabBar**

`news_screen.dart` 的 `build`：

1. Scaffold 外包 `DefaultTabController(length: 2)`
2. AppBar 加 `bottom: TabBar(tabs: [Tab(text: 'news.allNewsTab'.tr()), Tab(text: 'news.heatTab'.tr())])`
3. 既有 `body: Column(...)` 整段抽成私有 widget `_AllNewsTab`（原邏輯不動），
   body 改 `TabBarView(children: [_AllNewsTab(...), const HeatAnalysisTab()])`
4. 既有搜尋／重新整理行為只作用於全部新聞分頁；重新整理完成後
   `ref.invalidate(newsHeatProvider)` 讓熱度同步反映新抓的新聞

- [ ] **Step 6: 跑測試確認綠 + 既有 news_screen 測試不破**

Run: `flutter test test/presentation/screens/news/ test/presentation/providers/news_heat_provider_test.dart`
Expected: 全綠（若 `news_screen_test.dart` 因 TabBar 結構變動需調整 finder，
只改定位方式、不改行為斷言）

- [ ] **Step 7: 全套 + Commit**

```bash
flutter test
git add lib/presentation assets/translations test/presentation
git commit -m "feat(news-heat): 新聞頁熱度分析分頁（主流族群/焦點股/回檔過濾）"
```

---

### Task 9: 收尾驗證

**Files:**
- Modify: 無（驗證與推送）

- [ ] **Step 1: 全套測試 + analyze**

Run: `flutter test && flutter analyze --no-fatal-infos lib/`
Expected: 全綠、No issues

- [ ] **Step 2: 實機煙霧測試（使用者裝置）**

請使用者跑一次更新後打開新聞頁「熱度分析」：
- 族群卡片與焦點股是否合理（人工對照近期盤面）
- 「只看回檔中」過濾行為
- 更新 log 應出現快照寫入（或無錯誤）；用 sqlite 查
  `SELECT * FROM news_mention_daily ORDER BY date DESC LIMIT 20` 驗證落地

- [ ] **Step 3: Push**

```bash
git push
```

---

## Self-Review 紀錄

- Spec 覆蓋：匹配引擎（T1/T2）、題材字典（T1/T3）、熱度計算（T4）、
  快照表含 whitelist 與版本欄（T5/T6）、UI Tab 含回檔過濾（T7/T8）、
  fail-safe（T6）、語料稽核閘（T2）、實機驗證（T9）——spec 各節皆有對應 task。
- 型別一致性：`ArticleTags`/`StockHeat`/`ThemeHeat`/`HeatResult`（T4 定義、
  T6/T7/T8 消費）、`upsertMentionCounts`/`getMentionCounts`（T5 定義、T6 消費）、
  `NewsHeatAnalysis`（T7 定義、T8 消費）名稱與欄位已核對。
- 已知留白（皆為「照既有慣例填」而非 TBD）：deps/factory 注入寫法（T6）、
  in-memory DB 建構子名（T5）、個股詳情導航與 mode label（T8）——
  各處均附 grep 指令指向唯一正解。
