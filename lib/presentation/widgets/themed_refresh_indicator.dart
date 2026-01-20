import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// Default timeout duration for refresh operations
const _defaultTimeout = Duration(seconds: 30);

/// A themed RefreshIndicator with app colors and haptic feedback
class ThemedRefreshIndicator extends StatelessWidget {
  const ThemedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.timeout = _defaultTimeout,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final double displacement;
  final double edgeOffset;

  /// Timeout duration for the refresh operation (default: 30 seconds)
  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        try {
          await onRefresh().timeout(timeout);
        } on TimeoutException {
          // Silently handle timeout - the indicator will stop spinning
        }
        HapticFeedback.lightImpact();
      },
      displacement: displacement,
      edgeOffset: edgeOffset,
      color: AppTheme.primaryColor,
      backgroundColor: isDark ? const Color(0xFF2A2A3A) : Colors.white,
      strokeWidth: 2.5,
      child: child,
    );
  }
}

/// An animated refresh indicator with custom loading animation
class AnimatedRefreshIndicator extends StatefulWidget {
  const AnimatedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.timeout = _defaultTimeout,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  /// Timeout duration for the refresh operation (default: 30 seconds)
  final Duration timeout;

  @override
  State<AnimatedRefreshIndicator> createState() =>
      _AnimatedRefreshIndicatorState();
}

class _AnimatedRefreshIndicatorState extends State<AnimatedRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _controller.repeat();
    HapticFeedback.mediumImpact();

    try {
      await widget.onRefresh().timeout(widget.timeout);
    } on TimeoutException {
      // Silently handle timeout - the indicator will stop spinning
    } finally {
      _controller.stop();
      setState(() => _isRefreshing = false);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryColor,
      backgroundColor: isDark ? const Color(0xFF2A2A3A) : Colors.white,
      strokeWidth: 2.5,
      child: widget.child,
    );
  }
}
