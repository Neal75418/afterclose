import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';

/// 產業配置卡片
///
/// 以長條圖顯示投資組合的產業配置比例
class IndustryAllocationCard extends StatelessWidget {
  const IndustryAllocationCard({super.key, required this.allocation});

  final Map<String, IndustryAllocation> allocation;

  // 產業顏色映射 —— 依主題明暗分成兩組獨立色盤。
  //
  // 本卡片的實際渲染背景是 `theme.colorScheme.surfaceContainerLow`，淺色
  // 主題解析為 `#F8F9FA`、深色主題解析為 `#27272A`
  // （[SemanticColors.darkSurface]；surfaceContainerLow 在兩個主題都未
  // 個別指定，`??` 落回 surface，見 app_theme.dart 的說明）。過去用同一份
  // 色相清單套兩種主題，只驗證過深色，淺色從未被任何守門測試涵蓋，16 色
  // 中有 9 色對 `#F8F9FA` 低於圖形物件門檻 3.0:1（含最初只針對「其他電子業」
  // 换色的那次修復——新色值同樣沒驗淺色對比）。現在兩組色盤各自獨立設計、
  // 各自對其主題的實際背景驗證 ≥3.0:1，見
  // `test/presentation/screens/portfolio/widgets/industry_allocation_card_test.dart`
  // 的「產業色表守門」群組。
  //
  // 兩組色盤結構相同：7 個色相族（橘／琥珀／青／藍／紫／洋紅／粉）分散
  // 在排除紅綠禁區後的色相空間、彼此間距 >=35°（詳細數值見對應守門測試）。
  // 排除禁區後僅剩兩段安全弧（15°-88° 共 73°；175°-345° 共 170°），數學上
  // 分別最多容納 3 族／5 族間距 >=35° 的色相（(N-1)*35 <= 弧長），也就是
  // 至多 8 族——16 個產業必然有一半以上要共用色相族、靠明度而非色相區分。
  // 本次實際只用 7 族（安全弧起訖各保留邊界緩衝、放棄理論上限的第 8
  // 族），故「紫」族保留 3 個明度階承載原本就聚在同一色相帶的 3 個電腦
  // 相關產業、其餘 6 族各 2 階；同族（色相差 <=15°）以直接對比比值 >=1.5x
  // 區分明度，不落入「差不多但沒驗證」的中間地帶。「其他」改用不佔色相
  // 的純灰 `#808080`（對兩種背景皆 >=3.0:1），取代原本連淺色對比都不
  // 合格的 `CategoryColors.neutral`。
  static const industryColorsLight = <String, Color>{
    '半導體業': Color(0xFFAD14B2), // 洋紅族深階 — 298°
    '電腦及週邊設備業': Color(0xFF996EEF), // 電腦相關族淺階 — 260°
    '電子零組件業': Color(0xFF4C15BA), // 電腦相關族深階 — 260°
    '通信網路業': Color(0xFFE22FE8), // 洋紅族淺階 — 298°
    '光電業': Color(0xFFEB4789), // 粉族淺階 — 336°
    '其他電子業': Color(0xFF743AE9), // 電腦相關族中階 — 260°
    '電子通路業': Color(0xFFD36917), // 橘族淺階 — 26°
    '資訊服務業': Color(0xFF848D10), // 琥珀族淺階 — 64°
    '金融保險業': Color(0xFF0D6F75), // 青族深階 — 183°
    '航運業': Color(0xFF1956E5), // 藍族深階 — 222°
    '鋼鐵業': Color(0xFF12949E), // 青族淺階 — 184°
    '塑膠工業': Color(0xFF5582EC), // 藍族淺階 — 222°
    '食品工業': Color(0xFF9C4E11), // 橘族深階 — 26°
    '紡織纖維': Color(0xFF62690C), // 琥珀族深階 — 65°
    '生技醫療業': Color(0xFFC1155A), // 粉族深階 — 336°
    '其他': Color(0xFF808080), // 純灰，不佔色相
  };

  static const industryColorsDark = <String, Color>{
    '半導體業': Color(0xFFEE7EF2), // 洋紅族淺階 — 298°
    '電腦及週邊設備業': Color(0xFF9466F0), // 電腦相關族深階 — 260°
    '電子零組件業': Color(0xFFDFD2FA), // 電腦相關族淺階 — 260°
    '通信網路業': Color(0xFFDF17E6), // 洋紅族深階 — 298°
    '光電業': Color(0xFFEB3880), // 粉族深階 — 336°
    '其他電子業': Color(0xFFB899F5), // 電腦相關族中階 — 260°
    '電子通路業': Color(0xFFCC6414), // 橘族深階 — 26°
    '資訊服務業': Color(0xFF7F870D), // 琥珀族深階 — 64°
    '金融保險業': Color(0xFF14BAC6), // 青族淺階 — 184°
    '航運業': Color(0xFF87A8F3), // 藍族淺階 — 222°
    '鋼鐵業': Color(0xFF0F8F98), // 青族深階 — 184°
    '塑膠工業': Color(0xFF4B7CED), // 藍族深階 — 222°
    '食品工業': Color(0xFFEE934E), // 橘族淺階 — 26°
    '紡織纖維': Color(0xFFA6B111), // 琥珀族淺階 — 64°
    '生技醫療業': Color(0xFFF387B2), // 粉族淺階 — 336°
    '其他': Color(0xFF808080), // 純灰，不佔色相
  };

  Color _getColor(String industry, int index, Brightness brightness) {
    final table = brightness == Brightness.dark
        ? industryColorsDark
        : industryColorsLight;
    if (table.containsKey(industry)) {
      return table[industry]!;
    }
    // 備用顏色（當產業不在映射中時使用）—— 委派至通用圖表色盤，
    // 避免另立一份色相準則不同的清單。
    final fallback = CategoryColors.chartPaletteFor(brightness);
    return fallback[index % fallback.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (allocation.isEmpty) {
      return const SizedBox.shrink();
    }

    // 依比例排序
    final sorted = allocation.entries.toList()
      ..sort((a, b) => b.value.percentage.compareTo(a.value.percentage));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'portfolio.industryAllocation'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 長條圖
          for (var i = 0; i < sorted.length; i++) ...[
            _IndustryBar(
              industry: sorted[i].value.industry,
              percentage: sorted[i].value.percentage,
              symbols: sorted[i].value.symbols,
              color: _getColor(sorted[i].value.industry, i, theme.brightness),
              theme: theme,
            ),
            if (i < sorted.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _IndustryBar extends StatelessWidget {
  const _IndustryBar({
    required this.industry,
    required this.percentage,
    required this.symbols,
    required this.color,
    required this.theme,
  });

  final String industry;
  final double percentage;
  final List<String> symbols;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                industry,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          symbols.join(', '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
