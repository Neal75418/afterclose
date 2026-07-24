import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/event_calendar_provider.dart';

/// 即將到來事件摘要
///
/// [direction] horizontal＝水平捲動卡片（手機單欄）；vertical＝右欄
/// 直列展開（桌面雙欄）——**不自行捲動**，交由外層右欄統一捲，
/// 避免固定高度把卡片腰斬的裁切感。
class UpcomingEventsSection extends StatelessWidget {
  const UpcomingEventsSection({
    super.key,
    required this.events,
    this.onEventTap,
    this.direction = Axis.horizontal,
  });

  final List<StockEventEntry> events;
  final void Function(StockEventEntry event)? onEventTap;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: events.isEmpty
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing16,
                    vertical: DesignTokens.spacing8,
                  ),
                  child: Text(
                    'calendar.upcomingTitle'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (direction == Axis.horizontal)
                  SizedBox(
                    height: 76,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing12,
                      ),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _UpcomingEventCard(
                          event: events[index],
                          onTap: () => onEventTap?.call(events[index]),
                        );
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing12,
                    ),
                    child: Column(
                      children: [
                        for (final event in events)
                          _UpcomingEventCard(
                            event: event,
                            onTap: () => onEventTap?.call(event),
                            fullWidth: true,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: DesignTokens.spacing4),
              ],
            ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({
    required this.event,
    this.onTap,
    this.fullWidth = false,
  });

  final StockEventEntry event;
  final VoidCallback? onTap;

  /// true＝直列模式：卡片吃滿欄寬、高度自適應（標題不用 Expanded）
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = EventType.fromValue(event.eventType);
    final color = type.colorFor(theme.brightness);
    final date = event.eventDate;
    // 不依賴 EasyLocalization ancestor（context.locale）——MaterialApp 的
    // Localizations 就有 active locale，production 兩者同值、測試不用多包一層
    final localeName = Localizations.localeOf(context).toString();

    return Semantics(
      button: true,
      label: event.title,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: fullWidth ? null : 140,
          margin: fullWidth
              ? const EdgeInsets.symmetric(vertical: DesignTokens.spacing4)
              : const EdgeInsets.symmetric(horizontal: DesignTokens.spacing4),
          padding: const EdgeInsets.all(DesignTokens.spacing10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('MM/dd', localeName).format(date),
                    // 中性色：類型色只留左框——同類型事件連發時（如股東會季）
                    // 著色文字會把整欄漆成單一色海（2026-07-24 使用者回饋）
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    DateFormat.E(localeName).format(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing6),
              if (fullWidth)
                Text(
                  event.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
