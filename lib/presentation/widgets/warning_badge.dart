import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 警示標記類型
///
/// 優先級排序：處置 > 注意 > 高質押
enum WarningBadgeType {
  /// 處置股票（最高優先級）- 紅色警示
  disposal('處置', Icons.dangerous_rounded, AppTheme.errorColor),

  /// 注意股票 - 橘色警示
  attention('注意', Icons.warning_amber_rounded, AppTheme.tertiaryColor),

  /// 高質押比例 - 黃色警示
  highPledge('質押', Icons.account_balance_rounded, Colors.amber);

  const WarningBadgeType(this.label, this.icon, this.color);

  /// 顯示標籤
  final String label;

  /// 圖示
  final IconData icon;

  /// 主題色
  final Color color;
}

/// 警示標記 Widget
///
/// 用於在股票卡片上顯示警示狀態，支援三種類型：
/// - 處置股票（紅色）
/// - 注意股票（橘色）
/// - 高質押（黃色）
///
/// 視覺設計遵循 [ReasonTags] 的樣式，使用半透明背景與邊框。
///
/// 使用 [StatefulWidget] 確保動畫只在首次建構時執行，
/// 避免滾動清單時重複觸發動畫造成效能問題。
class WarningBadge extends StatefulWidget {
  const WarningBadge({
    super.key,
    required this.type,
    this.animate = true,
    this.showIcon = true,
    this.compact = true,
  });

  /// 警示類型
  final WarningBadgeType type;

  /// 是否啟用入場動畫
  final bool animate;

  /// 是否顯示圖示
  final bool showIcon;

  /// 是否使用緊湊模式（較小尺寸）
  final bool compact;

  @override
  State<WarningBadge> createState() => _WarningBadgeState();
}

class _WarningBadgeState extends State<WarningBadge> {
  /// 追蹤是否已播放過動畫，避免重複播放
  bool _hasAnimated = false;

  @override
  void didUpdateWidget(WarningBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當警示類型改變時，重置動畫狀態以便重新播放動畫
    // 這確保用戶能注意到重要的狀態變化（如從「注意」升級為「處置」）
    if (oldWidget.type != widget.type) {
      _hasAnimated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 只在首次建構時播放動畫
    final shouldAnimate = widget.animate && !_hasAnimated;
    if (shouldAnimate) {
      _hasAnimated = true;
    }

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 6 : 10,
        vertical: widget.compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: widget.type.color.withValues(alpha: isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(widget.compact ? 6 : 8),
        border: Border.all(
          color: widget.type.color.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1,
        ),
        // 處置股票加上微妙陰影增強視覺警示
        boxShadow: widget.type == WarningBadgeType.disposal
            ? [
                BoxShadow(
                  color: widget.type.color.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            Icon(
              widget.type.icon,
              size: widget.compact ? 12 : 14,
              color: widget.type.color,
            ),
            SizedBox(width: widget.compact ? 3 : 4),
          ],
          Text(
            widget.type.label,
            style:
                (widget.compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(
                      color: widget.type.color,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
          ),
        ],
      ),
    );

    // 入場動畫 - 只在首次建構時執行
    if (shouldAnimate) {
      badge = badge
          .animate()
          .fadeIn(duration: 200.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: 200.ms,
            curve: Curves.easeOut,
          );
    }

    // 無障礙標籤：為螢幕閱讀器提供語意資訊
    return Semantics(
      label: '${widget.type.label}警示',
      hint: _getAccessibilityHint(widget.type),
      child: badge,
    );
  }

  /// 取得無障礙提示文字
  String _getAccessibilityHint(WarningBadgeType type) {
    return switch (type) {
      WarningBadgeType.disposal => '此股票已被列入處置股票，交易受限',
      WarningBadgeType.attention => '此股票已被列入注意股票',
      WarningBadgeType.highPledge => '此股票董監質押比例偏高',
    };
  }
}

/// 警示標記覆蓋層
///
/// 用於在 Stack 中定位警示標記到右上角。
class WarningBadgeOverlay extends StatelessWidget {
  const WarningBadgeOverlay({
    super.key,
    required this.type,
    this.animate = true,
  });

  final WarningBadgeType type;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: WarningBadge(
        type: type,
        animate: animate,
        compact: true,
        showIcon: true,
      ),
    );
  }
}
