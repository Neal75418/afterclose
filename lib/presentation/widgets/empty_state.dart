import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';

/// Reusable empty state widget with animated illustration
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = iconColor ?? theme.colorScheme.primary;

    return Semantics(
      label:
          '$title${subtitle != null ? ', $subtitle' : ''}${actionLabel != null ? ', 按鈕: $actionLabel' : ''}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with background
              Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          effectiveColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          effectiveColor.withValues(
                            alpha: isDark ? 0.05 : 0.03,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: effectiveColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 56,
                      color: effectiveColor.withValues(alpha: 0.7),
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              // Title
              Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, duration: 400.ms),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.2, duration: 400.ms),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2, duration: 400.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pre-configured empty states for common scenarios
///
/// Uses [S] (AppStrings) for centralized string management,
/// enabling future i18n support.
class EmptyStates {
  EmptyStates._();

  /// No recommendations today
  static Widget noRecommendations({VoidCallback? onRefresh}) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: S.emptyNoRecommendations,
      subtitle: S.emptyNoRecommendationsHint,
      actionLabel: onRefresh != null ? S.refresh : null,
      onAction: onRefresh,
      iconColor: AppTheme.primaryColor,
    );
  }

  /// No stocks match filter
  static Widget noFilterResults({VoidCallback? onClearFilter}) {
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: S.emptyNoFilterResults,
      subtitle: S.emptyNoFilterResultsHint,
      actionLabel: onClearFilter != null ? S.emptyClearFilter : null,
      onAction: onClearFilter,
      iconColor: AppTheme.neutralColor,
    );
  }

  /// No stocks match filter - with detailed metadata
  static Widget noFilterResultsWithMeta({
    required String filterName,
    required String conditionDescription,
    required List<String> dataRequirements,
    String? thresholdInfo,
    int? totalScanned,
    DateTime? dataDate,
    VoidCallback? onClearFilter,
  }) {
    return _EmptyStateWithMeta(
      filterName: filterName,
      conditionDescription: conditionDescription,
      dataRequirements: dataRequirements,
      thresholdInfo: thresholdInfo,
      totalScanned: totalScanned,
      dataDate: dataDate,
      onClearFilter: onClearFilter,
    );
  }

  /// Empty watchlist
  static Widget emptyWatchlist({VoidCallback? onAdd}) {
    return EmptyState(
      icon: Icons.star_outline_rounded,
      title: S.emptyNoWatchlist,
      subtitle: S.emptyNoWatchlistHint,
      actionLabel: onAdd != null ? S.emptyGoToScan : null,
      onAction: onAdd,
      iconColor: Colors.amber,
    );
  }

  /// No news
  static Widget noNews({VoidCallback? onRefresh}) {
    return EmptyState(
      icon: Icons.article_outlined,
      title: S.emptyNoNews,
      subtitle: S.emptyNoNewsHint,
      actionLabel: onRefresh != null ? S.refresh : null,
      onAction: onRefresh,
      iconColor: AppTheme.secondaryColor,
    );
  }

  /// Error state
  static Widget error({required String message, VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: S.emptyError,
      subtitle: message,
      actionLabel: onRetry != null ? S.retry : null,
      onAction: onRetry,
      iconColor: AppTheme.errorColor,
    );
  }

  /// Network error
  static Widget networkError({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: S.emptyNetworkError,
      subtitle: S.emptyNetworkErrorHint,
      actionLabel: onRetry != null ? S.retry : null,
      onAction: onRetry,
      iconColor: AppTheme.errorColor,
    );
  }
}

/// Empty state widget with filter metadata information
class _EmptyStateWithMeta extends StatelessWidget {
  const _EmptyStateWithMeta({
    required this.filterName,
    required this.conditionDescription,
    required this.dataRequirements,
    this.thresholdInfo,
    this.totalScanned,
    this.dataDate,
    this.onClearFilter,
  });

  final String filterName;
  final String conditionDescription;
  final List<String> dataRequirements;
  final String? thresholdInfo;
  final int? totalScanned;
  final DateTime? dataDate;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.neutralColor.withValues(
                          alpha: isDark ? 0.15 : 0.1,
                        ),
                        AppTheme.neutralColor.withValues(
                          alpha: isDark ? 0.05 : 0.03,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.neutralColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_alt_off_outlined,
                    size: 48,
                    color: AppTheme.neutralColor.withValues(alpha: 0.7),
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.03, 1.03),
                  duration: 2.seconds,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 20),

            // Title with filter name
            Text(
              'filterMeta.titleWithFilter'.tr(
                namedArgs: {'filter': filterName},
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

            const SizedBox(height: 16),

            // Diagnostic Info (Scanned Count & Date)
            if (totalScanned != null || dataDate != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dataDate != null) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'filterMeta.labelDate'.tr(
                          namedArgs: {
                            'date': DateFormat('MM/dd').format(dataDate!),
                          },
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (totalScanned != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 12,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                    if (totalScanned != null) ...[
                      Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'filterMeta.labelScanned'.tr(
                          namedArgs: {
                            'count': NumberFormat.decimalPattern().format(
                              totalScanned,
                            ),
                          },
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
            ],

            // Condition description card
            Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Condition section
                      Row(
                        children: [
                          Icon(
                            Icons.rule_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'filterMeta.labelCondition'.tr(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        conditionDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      // Threshold info (if available)
                      if (thresholdInfo != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            thresholdInfo!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 24),

                      // Data requirements section
                      Row(
                        children: [
                          Icon(
                            Icons.storage_outlined,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'filterMeta.labelData'.tr(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: dataRequirements.map((req) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              req,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 200.ms, duration: 300.ms)
                .slideY(begin: 0.1, duration: 300.ms),

            const SizedBox(height: 16),

            // Hint text
            Text(
              'filterMeta.hintEmpty'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

            // Clear filter button
            if (onClearFilter != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                    onPressed: onClearFilter,
                    child: Text('filterMeta.labelClear'.tr()),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms)
                  .slideY(begin: 0.1, duration: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}
