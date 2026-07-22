import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/theme/design_tokens.dart';

/// 詳情頁底部「上一檔/下一檔」導航列
///
/// 顯示來源清單中的相鄰股票代碼與目前位置（n/N），供巡檢時免返回
/// 清單直接換股。無上一檔/下一檔時該側按鈕整個不顯示（首檔/尾檔）。
class StockNavBar extends StatelessWidget {
  const StockNavBar({
    super.key,
    required this.prev,
    required this.next,
    required this.position,
    required this.total,
    required this.onNavigate,
  });

  final String? prev;
  final String? next;
  final int position;
  final int total;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget side({
      required String? symbol,
      required IconData icon,
      required bool iconLeading,
    }) {
      if (symbol == null) return const SizedBox(width: 96);
      final label = Text(
        symbol,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
      return SizedBox(
        width: 96,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing4,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            onNavigate(symbol);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconLeading
                ? [Icon(icon, size: 20), Flexible(child: label)]
                : [Flexible(child: label), Icon(icon, size: 20)],
          ),
        ),
      );
    }

    // 明確鋪 surface 底色：詳情頁 body 漸層尾端是 colorScheme.surface，
    // Scaffold 的 bottomNavigationBar 槽預設卻是 scaffoldBackgroundColor
    // （深色主題兩者不同色），不鋪會出現一條色差接縫（審查發現）
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing8,
            vertical: DesignTokens.spacing4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              side(symbol: prev, icon: Icons.chevron_left, iconLeading: true),
              Text(
                '$position/$total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              side(symbol: next, icon: Icons.chevron_right, iconLeading: false),
            ],
          ),
        ),
      ),
    );
  }
}
