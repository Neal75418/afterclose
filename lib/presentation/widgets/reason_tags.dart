import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:daredevil/core/constants/api_config.dart';
import 'package:daredevil/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:daredevil/domain/models/signal_names.dart';
import 'package:daredevil/core/constants/reason_type.dart';
import 'package:daredevil/core/theme/app_theme.dart';
import 'package:daredevil/core/theme/semantic_colors.dart';
import 'package:daredevil/core/theme/design_tokens.dart';

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
    this.isCalibrationBacked,
  });

  /// 要顯示的原因標籤或代碼列表
  final List<String> reasons;

  /// 標籤的尺寸變體
  final ReasonTagSize size;

  /// 最多顯示的標籤數量（null = 顯示全部）
  final int? maxTags;

  /// 是否翻譯原因代碼（用於原始資料庫代碼）
  final bool translateCodes;

  /// 判定某 reason code 是否經回測校準背書（有真 edge）。
  ///
  /// null → 用 [CalibratedScoresRegistry.instance]（production 預設）；
  /// 測試可注入 fake predicate。**僅在 [translateCodes] 為 true 時生效**
  /// （否則 reasons 是已翻譯 label 非 code，無法對應校準狀態）。
  final bool Function(String code)? isCalibrationBacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.isDark;

    final displayReasons = maxTags != null ? reasons.take(maxTags!) : reasons;

    final isCompact = size == ReasonTagSize.compact;
    final backedFn =
        isCalibrationBacked ??
        (code) => CalibratedScoresRegistry.instance.isCalibrationBacked(code);

    return Wrap(
      spacing: isCompact ? DesignTokens.spacing6 : DesignTokens.spacing8,
      runSpacing: isCompact ? DesignTokens.spacing4 : DesignTokens.spacing8,
      children: displayReasons.map((reason) {
        final label = translateCodes ? translateReasonCode(reason) : reason;
        // 校準背書僅在 translateCodes（reason 是 code）時可判定
        final backed = translateCodes && backedFn(reason);
        final baseTooltip = translateCodes
            ? tooltipForReasonCode(reason)
            : null;
        final tooltip = backed
            ? [
                ?baseTooltip,
                'reasonTags.calibrationBackedNote'.tr(),
              ].join('\n\n')
            : baseTooltip;
        return _ReasonTag(
          isRisk: translateCodes && SignalName.maStageBreak.contains(reason),
          label: label,
          tooltip: tooltip,
          isCompact: isCompact,
          isDark: isDark,
          theme: theme,
          isBacked: backed,
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
    this.isRisk = false,
    required this.label,
    this.tooltip,
    required this.isCompact,
    required this.isDark,
    required this.theme,
    this.isBacked = false,
  });

  final String label;
  final String? tooltip;
  final bool isCompact;
  final bool isDark;
  final ThemeData theme;

  /// 經回測校準背書（有真 edge）→ 加 verified 標記
  final bool isBacked;

  /// 風控警示 tag(跌破月線/季線,2026-07-31):error 語意色——沿用
  /// 更新失敗 badge 的先例;紅綠專屬股價漲跌的紀律不涵蓋 error 語意。
  final bool isRisk;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? DesignTokens.spacing8 : DesignTokens.spacing12,
        vertical: isCompact ? DesignTokens.spacing4 : DesignTokens.spacing6,
      ),
      decoration: BoxDecoration(
        // isRisk 背景/文字用 AppTheme.errorColor 家族(WarningBadge 同源):
        // ErrorColors.onTint* 是對「errorColor tint 合成背景」實測校準的
        // (4.9~5.5:1),colorScheme.error(#FF6B6B)自疊僅 ~3.6:1 不合格
        color: isRisk
            ? AppTheme.errorColor.withValues(
                alpha: isDark ? DesignTokens.opacity25 : DesignTokens.opacity10,
              )
            : isDark
            ? AppTheme.brandDecorative.withValues(alpha: DesignTokens.opacity25)
            : AppTheme.primaryColor.withValues(alpha: DesignTokens.opacity10),
        borderRadius: BorderRadius.circular(
          isCompact ? DesignTokens.radiusSm : DesignTokens.radiusMd,
        ),
        border: isDark
            ? Border.all(
                color: AppTheme.brandDecorative.withValues(
                  alpha: DesignTokens.opacity40,
                ),
                width: 1,
              )
            : null,
      ),
      child: _content(
        Text(
          label,
          style:
              (isCompact
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                    // 文字承載對比義務。深色主題的底色（見上方 decoration）是
                    // brandDecorative 以 25% alpha 疊加卡片背景的合成色，而非
                    // 平面背景——colorScheme.primary（解析為 brand）只對平面
                    // 背景校準過對比度，對此合成色僅 4.1:1，故改用專為此疊色
                    // 情境校準的 brandOnDecorative（見
                    // test/core/theme/semantic_colors_test.dart 疊色守門測試）。
                    // 淺色主題底色是 primaryColor 10% 疊白，colorScheme.primary
                    // （解析為 brandOnLight）仍合格，維持不變。
                    color: isRisk
                        ? ErrorColors.onTintFor(
                            isDark ? Brightness.dark : Brightness.light,
                          )
                        : isDark
                        ? AppTheme.brandOnDecorative
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
        ),
      ),
    );

    if (tooltip == null) return tag;

    return _wrapTooltip(tag);
  }

  /// 背書時在 label 前加 verified 小標記
  Widget _content(Widget text) {
    if (!isBacked) return text;
    final color = isDark
        ? AppTheme.brandOnDecorative
        : theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_outlined, size: isCompact ? 12 : 14, color: color),
        SizedBox(
          width: isCompact ? DesignTokens.spacing4 : DesignTokens.spacing6,
        ),
        text,
      ],
    );
  }

  Widget _wrapTooltip(Widget tag) {
    return Tooltip(
      message: tooltip!,
      preferBelow: true,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: ApiConfig.longMessageDurationSec),
      child: tag,
    );
  }
}
