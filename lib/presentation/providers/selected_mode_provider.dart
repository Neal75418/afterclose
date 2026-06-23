import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';

/// 當前使用者在 Today screen 選擇的 mode（3-tab UI 主軸）
///
/// mode 決定看哪類訊號（起漲 / 強勢 / 弱勢）。
///
/// （歷史：原與全域 horizon 開關正交共存，但該開關已於 2026-06 移除；scan 定死
/// 60D、stock detail / comparison 定死 5D。）
///
/// ## 為什麼是全域 state 但只給 Today 用
///
/// 用全域 state 保留未來擴展空間（例如 watchlist tab 想 reuse mode filter 時
/// 不需重構）。
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
