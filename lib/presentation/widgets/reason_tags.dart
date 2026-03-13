import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 推薦原因標籤的尺寸變體
enum ReasonTagSize {
  /// 精簡尺寸，適用於卡片視圖（較小的間距與文字）
  compact,

  /// 標準尺寸，適用於詳情視圖
  normal,
}

/// 可重用的推薦原因標籤 Widget，具有一致的樣式
class ReasonTags extends StatelessWidget {
  const ReasonTags({
    super.key,
    required this.reasons,
    this.size = ReasonTagSize.normal,
    this.maxTags,
    this.translateCodes = false,
  });

  /// 要顯示的原因標籤或代碼列表
  final List<String> reasons;

  /// 標籤的尺寸變體
  final ReasonTagSize size;

  /// 最多顯示的標籤數量（null = 顯示全部）
  final int? maxTags;

  /// 是否翻譯原因代碼（用於原始資料庫代碼）
  final bool translateCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.isDark;

    final displayReasons = maxTags != null ? reasons.take(maxTags!) : reasons;

    final isCompact = size == ReasonTagSize.compact;

    return Wrap(
      spacing: isCompact ? DesignTokens.spacing6 : DesignTokens.spacing8,
      runSpacing: isCompact ? DesignTokens.spacing4 : DesignTokens.spacing8,
      children: displayReasons.map((reason) {
        final label = translateCodes ? translateReasonCode(reason) : reason;
        final tooltip = translateCodes ? tooltipForReasonCode(reason) : null;
        return _ReasonTag(
          label: label,
          tooltip: tooltip,
          isCompact: isCompact,
          isDark: isDark,
          theme: theme,
        );
      }).toList(),
    );
  }

  /// 將資料庫原因代碼轉換為翻譯後的標籤
  ///
  /// 支援 SNAKE_CASE（DB 原始碼）與 camelCase（JSON 格式）兩種格式。
  static String translateReasonCode(String code) {
    final type = reasonTypeFromCode(code);
    if (type == null) return code;
    return type.i18nLabelKey.tr();
  }

  /// 取得原因代碼的說明文字（用於 tooltip）
  ///
  /// 對應 summary.* / reasonTip.* 的 i18n 鍵中的描述性句子。
  static String? tooltipForReasonCode(String code) {
    final type = reasonTypeFromCode(code);
    if (type == null) return null;
    final key = type.i18nTooltipKey;
    if (key == null) return null;
    final translated = key.tr();
    // 若翻譯結果等於 key 本身，表示缺少翻譯
    return translated == key ? null : translated;
  }
}

class _ReasonTag extends StatelessWidget {
  const _ReasonTag({
    required this.label,
    this.tooltip,
    required this.isCompact,
    required this.isDark,
    required this.theme,
  });

  final String label;
  final String? tooltip;
  final bool isCompact;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? DesignTokens.spacing8 : DesignTokens.spacing12,
        vertical: isCompact ? DesignTokens.spacing4 : DesignTokens.spacing6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.secondaryColor.withValues(alpha: DesignTokens.opacity25)
            : AppTheme.primaryColor.withValues(alpha: DesignTokens.opacity10),
        borderRadius: BorderRadius.circular(
          isCompact ? DesignTokens.radiusSm : DesignTokens.radiusMd,
        ),
        border: isDark
            ? Border.all(
                color: AppTheme.secondaryColor.withValues(
                  alpha: DesignTokens.opacity40,
                ),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style:
            (isCompact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
                  color: isDark
                      ? AppTheme.secondaryColor
                      : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
      ),
    );

    if (tooltip == null) return tag;

    return Tooltip(
      message: tooltip!,
      preferBelow: true,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: tag,
    );
  }
}
