import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:daredevil/core/theme/design_tokens.dart';
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/domain/services/alert/alert_target_calculator.dart';

/// 快捷提醒鈕(2026-08-07)。
///
/// 存在理由:使用者要的是「**觸價後開始觀察**再自己決定」,不是每次手打
/// 價位。所以 app 把 5MA / 10MA / 月線 / 20 日高 / 守門價都算好放著——
/// **只算不決定**,點哪個、要不要點,主動權 100% 在使用者。
///
/// 建立動作刻意交給 [onSelected] 的呼叫端:這個 widget 不碰 provider,
/// 純顯示+回報,單元測試不需要 Riverpod harness。
class AlertQuickSet extends StatelessWidget {
  const AlertQuickSet({
    super.key,
    required this.bars,
    required this.onSelected,
    this.currentPrice,
    this.existingTargets = const {},
  });

  /// 日線(依日期升冪,最後一筆最新)
  final List<Ohlc> bars;

  final void Function(AlertKind kind, AlertTarget target) onSelected;

  /// 現價;給定時用來停用「條件已成立」的種類——設了會立刻觸發一次
  /// 就結束,是純噪音(2026-08-07 實機:緯創 183.5 已在 5MA 189.4 之下、
  /// 月線 166.3 之上,兩顆按鈕形同陷阱)。null=不臆測,全部可點。
  final double? currentPrice;

  /// 本檔已存在的提醒目標價。命中者停用——同一顆點兩次會建出兩筆一模
  /// 一樣的提醒(2026-08-08 實機重現),而兩筆都會各叫一次。
  final Set<double> existingTargets;

  /// DB 價格列 → 計算用單位。**明確依日期升冪排序**,不假設 DAO 的
  /// 回傳方向(2026-08-07 實機 bug:接線處誤以為是降冪而多 reversed 一次,
  /// 均線改用最舊的幾根算出來——緯創現價 183.5 卻顯示 5MA 122.8、
  /// 「20 日高」128.0 低於現價)。OHLC 任一缺值或收盤 ≤0 的列略過(停牌)。
  static List<Ohlc> toOhlc(List<DailyPriceEntry> history) {
    final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final p in sorted)
        if (p.high != null && p.low != null && p.close != null && p.close! > 0)
          Ohlc(high: p.high!, low: p.low!, close: p.close!),
    ];
  }

  /// 顯示順序:由緊到鬆的支撐,再到突破,守門價殿後(它是風控不是機會)
  static const _order = [
    AlertKind.breakBelowMa5,
    AlertKind.breakBelowMa10,
    AlertKind.breakBelowMa20,
    AlertKind.breakAboveMa20,
    AlertKind.breakAbove20DayHigh,
    AlertKind.stopGate,
  ];

  /// 條件是否已成立(向上型:現價已在目標之上;向下型:已在其下)
  /// 已有同價位的提醒?浮點比較用 0.005 容差(顯示精度是兩位小數)
  bool _alreadySet(AlertTarget t) =>
      existingTargets.any((e) => (e - t.price).abs() < 0.005);

  bool _isAlreadyMet(AlertTarget t) {
    final p = currentPrice;
    if (p == null) return false;
    return t.isUpward ? p >= t.price : p <= t.price;
  }

  @override
  Widget build(BuildContext context) {
    final targets = AlertTargetCalculator.compute(bars);
    if (targets.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'alert.quickSet.hint'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.spacing8),
        Wrap(
          spacing: DesignTokens.spacing8,
          runSpacing: DesignTokens.spacing8,
          children: [
            for (final kind in _order)
              if (targets[kind] case final t?)
                Builder(
                  builder: (context) {
                    final met = _isAlreadyMet(t);
                    final dup = _alreadySet(t);
                    return ActionChip(
                      avatar: Icon(
                        (met || dup)
                            ? Icons.check_circle_outline
                            : (t.isUpward
                                  ? Icons.trending_up
                                  : Icons.trending_down),
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        dup
                            ? '${'alert.quickSet.${kind.name}'.tr()} '
                                  '${t.price.toStringAsFixed(2)} · '
                                  '${'alert.quickSet.alreadySet'.tr()}'
                            : met
                            ? '${'alert.quickSet.${kind.name}'.tr()} '
                                  '${t.price.toStringAsFixed(2)} · '
                                  '${'alert.quickSet.alreadyMet'.tr()}'
                            : '${'alert.quickSet.${kind.name}'.tr()} '
                                  '${t.price.toStringAsFixed(2)}',
                      ),
                      // 條件已成立 → 停用。標籤仍顯示,讓這排按鈕同時
                      // 是「現價相對各條線在哪」的狀態讀數。
                      onPressed: (met || dup)
                          ? null
                          : () => onSelected(kind, t),
                    );
                  },
                ),
          ],
        ),
      ],
    );
  }
}
