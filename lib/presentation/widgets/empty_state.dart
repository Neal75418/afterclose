import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      label: '$title${subtitle != null ? ', $subtitle' : ''}${actionLabel != null ? ', 按鈕: $actionLabel' : ''}',
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
                    effectiveColor.withValues(alpha: isDark ? 0.05 : 0.03),
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
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
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
      iconColor: AppTheme.upColor,
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
      iconColor: AppTheme.upColor,
    );
  }
}
