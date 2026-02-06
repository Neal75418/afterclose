import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/theme/app_theme.dart';

/// 重新整理操作的預設逾時時間
const _defaultTimeout = Duration(seconds: 30);

/// 套用主題色與觸覺回饋的 RefreshIndicator
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

  /// 重新整理操作的逾時時間（預設 30 秒）
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
          // 逾時靜默處理 — indicator 會自動停止旋轉
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

/// 帶自訂載入動畫的 RefreshIndicator
class AnimatedRefreshIndicator extends StatefulWidget {
  const AnimatedRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.timeout = _defaultTimeout,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  /// 重新整理操作的逾時時間（預設 30 秒）
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
      duration: AnimDurations.loading,
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
      // 逾時靜默處理 — indicator 會自動停止旋轉
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
