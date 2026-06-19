/// 篩選模式 — Today screen 主 tab 的分類軸
///
/// **動機**：使用者用 AfterClose 不是只找「會漲的股票」，是 3 種觀察心智：
/// - Mode A：起漲候選 — 找還沒漲但有起漲訊號的股票（進場前的研究）
/// - Mode B：強勢觀察 — 已大漲的股票，等回檔時機進場
/// - Mode C：弱勢觀察 — 已下跌的股票，確認是否真的轉空（避開或反向）
///
/// 跟 [Horizon] 是**正交**的兩個維度：mode 是用戶的觀察類型、horizon 是
/// 評估的時間軸。同一檔股票可同時出現在多個 mode、每個 mode 內各有 5D
/// 跟 60D 兩個 score。
enum ScoringMode {
  /// 起漲候選 — 反轉 / 突破 / 底部訊號
  ///
  /// 用於「我想找還沒漲、即將起漲的股票」。
  /// 包含：弱轉強、技術突破、看多 K 線型態、業績反轉、月增動能、ROE 改善、
  /// 內部人大量買、PBR 低估（唯一有 backtest alpha 的 value rule）。
  momentumEntry,

  /// 強勢觀察 — 已漲、等回檔
  ///
  /// 用於「我想追蹤強勢股、等回檔機會進場」。
  /// 包含：大漲、跳空、52 週高、法人連買、外資加碼、KD 黃金、爆量、新聞
  /// 帶量、RSI 超買（警示中夾雜進場資訊）。
  strengthObserve,

  /// 弱勢觀察 — 已跌、確認轉空 / 避開
  ///
  /// 用於「我想確認某檔是不是真的崩了、要不要避開或反向」。
  /// 包含：強轉弱、跌破支撐、看空 K 線、52 週低、空頭排列、超賣、外資減
  /// 碼、法人連賣、注意股 / 處置股、內部人連賣、質押風險、估值過高、
  /// 營收年減、EPS 衰退、ROE 下滑。
  weaknessObserve,

  /// 中性 — 不貢獻任何 mode score（背景 filter / value rule）
  ///
  /// 這些 rule 仍會 fire 寫進 daily_reason、evidence chip 仍顯示，但**不影響**
  /// 任何 mode 的排名。包含：CONCENTRATION_HIGH（已 demote）、REVENUE_NEW_HIGH
  /// （已 demote）、HIGH_DIVIDEND_YIELD（value 非 momentum）、PE_UNDERVALUED
  /// （跟 PBR_UNDERVALUED redundant）等。
  ///
  /// 等 calibration 累積資料、threshold 調好後可考慮重新歸類。
  neutral;

  /// 中文顯示名
  String get displayKey => switch (this) {
    ScoringMode.momentumEntry => 'scoringMode.momentumEntry',
    ScoringMode.strengthObserve => 'scoringMode.strengthObserve',
    ScoringMode.weaknessObserve => 'scoringMode.weaknessObserve',
    ScoringMode.neutral => 'scoringMode.neutral',
  };

  /// Tab 圖示
  ///
  /// 不直接 import Material — 由 UI 層 mapping，這個檔保持 pure Dart。
  String get iconKey => switch (this) {
    ScoringMode.momentumEntry => 'trending_up', // Icons.trending_up
    ScoringMode.strengthObserve => 'bolt', // Icons.bolt
    ScoringMode.weaknessObserve => 'warning', // Icons.warning_amber
    ScoringMode.neutral => 'circle_outlined',
  };

  /// Tab 是否在 Today 顯示（neutral 不顯示為 tab）
  bool get isUserFacing => this != ScoringMode.neutral;

  /// User-facing modes (Today screen tabs)
  static const userFacingModes = [
    ScoringMode.momentumEntry,
    ScoringMode.strengthObserve,
    ScoringMode.weaknessObserve,
  ];
}
