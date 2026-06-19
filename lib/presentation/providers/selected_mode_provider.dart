import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';

/// 當前使用者在 Today screen 選擇的 mode（3-tab UI 主軸）
///
/// 跟 [selectedHorizonProvider] **正交共存**：mode 決定看哪類訊號（起漲 /
/// 強勢 / 弱勢），horizon 決定卡片內 5D / 60D score 哪個當主排序。
///
/// ## 為什麼是全域 state 但只給 Today 用
///
/// Stock detail / scan / comparison 維持 horizon-based 不動（hybrid 設計
/// Option B），所以這個 provider 不像 [selectedHorizonProvider] 跨多個
/// screen 共享 — 但仍用全域 state 保留未來擴展空間（例如 watchlist tab
/// 想 reuse mode filter 時不需重構）。
///
/// ## 生命週期
///
/// - 預設為 [ScoringMode.momentumEntry]（找起漲是 user 主要使用情境）
/// - 非持久化：重開 app 回到 default
class SelectedModeNotifier extends Notifier<ScoringMode> {
  @override
  ScoringMode build() => ScoringMode.momentumEntry;

  void select(ScoringMode mode) {
    if (!mode.isUserFacing) return; // neutral 不應該被 select
    state = mode;
  }
}

final selectedModeProvider =
    NotifierProvider<SelectedModeNotifier, ScoringMode>(
      SelectedModeNotifier.new,
    );
