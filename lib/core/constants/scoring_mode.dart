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

/// Mode-aware UI filter thresholds（2026-06-19 audit Action 5）
///
/// 治掉「**已大漲股票卡在 Mode A 起漲候選**」與「**漲停股出現在 Mode C 弱勢
/// 觀察**」兩種違反 mental model 的 case：
/// - 1907 永豐餘 5D +9.73% 還在「起漲」（已漲一波）
/// - 4551 智伸科 漲停 +9.93% 還在「弱勢」（RSI 超買 + 吊人線 fires 但今天漲）
///
/// 跟 mode-aware sort（[ScoringMode.weaknessObserve] 用 sum ASC）配套：先按
/// score 排再 anti-filter、被踢的不算 quota；filter 後不足 30 也照舊。
abstract final class ModeFilters {
  /// Mode A（起漲候選）剔除 5 日漲幅 > 8% 的股票
  ///
  /// 「起漲」mental model = 還沒漲、即將漲。一週已漲 >8% 不符合此定義。
  /// **但**強訊號（[modeAStrongScoreOverride] 以上）例外保留 — 反轉訊號
  /// 規則本身就帶「起漲」語意（REVERSAL_W2S +35），即使技術面顯示已漲、
  /// 規則仍判斷是底部起漲確認、不該被技術 filter 蓋過。
  static const double modeAExclude5dPct = 8.0;

  /// Mode A 強訊號豁免分數：sum_short ≥ 50 不受 5D filter 影響
  ///
  /// 對應「REVERSAL_W2S +35 + 其他輔助訊號 ≥ 15」的組合，明確的反轉確認
  /// 而非單一弱訊號。e.g. 6770 力積電（弱轉強 35 + 晨星 25 = 60）即使 5D
  /// 漲 15%、仍是真起漲、應保留。
  ///
  /// **2026-06-19 audit Action 5b**：豁免**只作用於 5D filter**、不豁免
  /// [modeAExcludeTodayPct]。理由：今日 gap-up +9% 即使有最強反轉訊號、
  /// 對 user mental model 已是「**追高**」而非「起漲」；這檔股票同時應該
  /// 在 Mode B 有訊號（強勢確認）、filter-aware assign 會自動把它導去 B。
  static const double modeAStrongScoreOverride = 50;

  /// Mode A 剔除「**當日**漲幅 > 8%」（無豁免）
  ///
  /// 跟 [modeAExclude5dPct] 互補：5D filter 擋「一週累積已漲多」、今日 filter
  /// 擋「**今天突然爆衝**」。原本只有 5D 抓不到「5D 累積還沒 +8% 但今天 gap
  /// up +9.92% 漲停」的 case（6651 全宇昕、3090 日電貿等）。
  ///
  /// **沒有強訊號豁免**：分數再高（如 60 分弱轉強+晨星）、今天就漲 +9% 也
  /// 算已過起漲點。filter-aware assign 會自動把這檔分派到 Mode B 強勢觀察
  /// （該檔同時應有 Mode B 訊號）。
  ///
  /// 跟 [modeCExcludeTodayPct] (0%) 同一條 user mental model 軸：
  /// - 起漲候選：今日漲幅應「適度」（≤ 8%）
  /// - 弱勢觀察：今日漲幅應「不正」（≤ 0%）
  static const double modeAExcludeTodayPct = 8.0;

  /// Mode C（弱勢觀察）剔除「當日上漲」的股票
  ///
  /// 「弱勢」mental model = 已下跌 / 正在轉空。今日只要紅 K（> 0%）就跟
  /// 「弱勢」前提衝突 — 即使 RSI 超買 / PE 高估等警示 fires、那是「過熱
  /// 風險」不是「下跌中」、不該指派到弱勢 tab。
  ///
  /// **2026-06-19 audit 從 +5% 收緊到 0%**：5% 留太多「今天反彈但有警示」
  /// case 在弱勢 tab、user mental model 對不上。0% 嚴格界定「**今日收紅 =
  /// 不算弱勢**」。strict `>` 比較讓 0.00% 平盤 stays（合理：平盤不算漲）。
  static const double modeCExcludeTodayPct = 0.0;

  /// 指派 floor：best-eligible mode 的 |modeScoreShort| 必須 ≥ 10 才指派
  ///
  /// 避免 eligibility-first 把「主要 mode 不合格、次要 mode 只有 trivial
  /// 分數」的股票塞進非主要 tab。
  ///
  /// 範例：股票 X 有 A=80（但 today +10% 被擋）/ B=0 / C=-2（today -1%）
  /// - 無 floor：C(-2) 是唯一合格 → 出現在 Mode C 弱勢 tab 但 score -2
  ///   是噪音、排在 -50 處置股下面也很怪
  /// - 有 floor ≥ 10：bestAbs = 2 < 10 → 整檔 drop ✅（今天訊號狀態不穩、
  ///   跳過比誤導好）
  static const int minRoutedAbsScore = 10;
}
