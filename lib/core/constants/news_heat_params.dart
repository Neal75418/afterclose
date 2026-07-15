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
    '鴻海',
    '聯電',
    '台塑',
    '廣達',
    '緯創',
    '華碩',
    '群創',
    '友達',
    '國巨',
    '華航',
    '陽明',
    '長榮',
    '萬海',
    '中鋼',
    '台泥',
    '亞泥',
    '台化',
    '南亞',
    '台達',
    '和碩',
    '仁寶',
    '英韌',
    '智邦',
    '光寶',
    '研華',
    '威剛',
    '南電',
    '景碩',
    '欣興',
    '健鼎',
    '金像',
    '嘉澤',
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
