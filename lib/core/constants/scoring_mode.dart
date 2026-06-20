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
  ///
  /// **2026-06-19 v2**：weaknessObserve 從 `warning` 改 `south_east`（向下回檔
  /// 感、觀察機會、不再是警示）— 對應 Mode C 從「弱勢警示」改為「回檔進場」語意。
  String get iconKey => switch (this) {
    ScoringMode.momentumEntry => 'trending_up', // Icons.trending_up
    ScoringMode.strengthObserve => 'bolt', // Icons.bolt
    ScoringMode.weaknessObserve => 'south_east', // Icons.south_east
    ScoringMode.neutral => 'circle_outlined',
  };

  /// Mode routing priority — eligibility-first assignment 時的優先順序
  ///
  /// **2026-06-19 v2 audit 引入**：當一檔股票對多個 mode 都 eligible（罕見、但
  /// edge case 存在）時，按此優先順序選擇 mode，數字越大優先級越高、tiebreak 用
  /// max |modeScoreShort|。
  ///
  /// 設計理由：
  /// - **weaknessObserve (pullbackEntry) 3 — 最 actionable**：「強股回檔進場」是
  ///   user 真正下單的時刻、最該被 surface 出來
  /// - **momentumEntry 2 — 中**：「起漲候選」是研究階段
  /// - **strengthObserve 1 — 監控**：「強勢觀察」純監控、不急
  ///
  /// 實務上 Mode B / Mode C eligibility 已透過 todayPct (>0 vs ≤0) 互斥，這個
  /// priority 主要處理 Mode A / Mode C 邊界 case（罕見）。
  int get routingPriority => switch (this) {
    ScoringMode.weaknessObserve => 3, // pullbackEntry — 最 actionable
    ScoringMode.momentumEntry => 2,
    ScoringMode.strengthObserve => 1,
    ScoringMode.neutral => 0,
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
  /// 跟 [modeCMaxTodayPct] (0%) 同一條 user mental model 軸：
  /// - 起漲候選：今日漲幅應「適度」（≤ 8%）
  /// - 弱勢觀察：今日漲幅應「不正」（≤ 0%）
  static const double modeAExcludeTodayPct = 8.0;

  /// Mode C（回檔觀察 v2）今日漲幅上限
  ///
  /// **2026-06-19 v2 audit 重定義 Mode C 為「強股回檔進場」**：今日須收黑或平盤
  /// 才算「剛開始回檔」、上漲就不是回檔。strict `>` 比較讓 0.00% 平盤 stays。
  static const double modeCMaxTodayPct = 0.0;

  /// Mode C 今日跌幅下限（-4%、深 V 不算健康回檔）
  ///
  /// 「健康回檔」mental model = 強股**小幅**拉回提供進場時機。今日大跌 > 4% 通常
  /// 是恐慌賣壓 / 突發利空、不是 sweet spot 進場點。設 -4% 作 floor 過濾深 V。
  ///
  /// **CALIBRATION_PENDING**：-4% 是直覺值、缺 backtest。上線後看實際 fire 範圍
  /// 再調。
  static const double modeCMinTodayPct = -4.0;

  /// Mode C 最低 mode score（≥ +12）
  ///
  /// v2 Mode C 從「全負分警示」改為「正分機會」tab、score 門檻改正分。+12 對應
  /// 最弱的主訊號 `kdHighPullback`（單獨 fire 也夠 actionable）。
  static const double modeCMinScore = 12.0;

  /// Mode C eligibility 必過 gate：至少 1 條主訊號 rule fire
  ///
  /// 3 條主訊號 rule 提供「回檔進場時機」確認、舊負分 warning rule 單獨 fire 不
  /// 足以入 Mode C（避免「純警示無進場點」雜訊）。
  ///
  /// 這 3 條 rule 識別子用字串避免循環 import（ReasonType import scoring_mode、
  /// 反方向會 cycle）— 從 ReasonType.code 比對。
  ///
  /// **2026-06-20 早期體檢修正**：移除 PATTERN_HAMMER。HammerRule 要 trendState
  /// != up 才 fire、跟 Mode C「強股回檔」(trendState == up) 互斥 → 永遠 0 fire
  /// 的死碼 gate 入口。已搬回 Mode A、強股錘子角色由 HAMMER_AT_SUPPORT 擔。
  static const Set<String> modeCRequiredAnyOf = {
    'PULLBACK_TO_MA20',
    'HAMMER_AT_SUPPORT',
    'KD_HIGH_PULLBACK',
  };

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
