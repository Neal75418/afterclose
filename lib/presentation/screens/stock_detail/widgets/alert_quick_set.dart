import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:daredevil/core/theme/design_tokens.dart';
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
  });

  /// 日線(依日期升冪,最後一筆最新)
  final List<Ohlc> bars;

  final void Function(AlertKind kind, AlertTarget target) onSelected;

  /// 顯示順序:由緊到鬆的支撐,再到突破,守門價殿後(它是風控不是機會)
  static const _order = [
    AlertKind.breakBelowMa5,
    AlertKind.breakBelowMa10,
    AlertKind.breakBelowMa20,
    AlertKind.breakAboveMa20,
    AlertKind.breakAbove20DayHigh,
    AlertKind.stopGate,
  ];

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
                ActionChip(
                  avatar: Icon(
                    t.isUpward ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    '${'alert.quickSet.${kind.name}'.tr()} '
                    '${t.price.toStringAsFixed(1)}',
                  ),
                  onPressed: () => onSelected(kind, t),
                ),
          ],
        ),
      ],
    );
  }
}
