import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 產業表現區域
///
/// 顯示各產業的平均漲跌幅、漲跌家數（等權平均）。
/// 桌面版取前/後榜排成 4 欄格線，手機版水平捲動顯示完整排名。
/// 標頭以 [Wrap] 排列口徑／大盤錨點，窄螢幕自動換行避免溢出。市場脈絡已由
/// 外層版面的加權指數／櫃買指數 Hero 區塊錨定，本區不再重複標示市場。
class IndustryPerformanceRow extends StatelessWidget {
  const IndustryPerformanceRow({
    super.key,
    required this.industries,
    required this.indexChangePercent,
  });

  final List<IndustrySummary> industries;

  /// 大盤（對應市場 Hero 指數）漲跌幅（%），供標頭錨點顯示；null 時不顯示
  final double? indexChangePercent;

  /// 桌面 Wrap 模式最多顯示的產業數量（前 N + 後 N，對稱）
  static const _desktopMaxItems = 8;

  /// 依顯示精度捨入（供文字與配色共用同一個值——顯示 0.0% 就不得著漲跌色）
  static double roundForDisplay(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals));

  /// 格式化帶正負號的百分比：**先依 [decimals] 捨入再判正負**，
  /// 避免微負值（如 -0.04 取一位）顯示成「-0.0%」負零。
  static String formatSignedPct(double value, int decimals) {
    final rounded = roundForDisplay(value, decimals);
    if (rounded == 0) return '${0.0.toStringAsFixed(decimals)}%';
    return '${rounded > 0 ? '+' : ''}${rounded.toStringAsFixed(decimals)}%';
  }

  /// 卡片固定高度：容納「產業名／漲跌幅+家數／5日動能（選填）」三行內容
  static const _cardHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    if (industries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= Breakpoints.mobile;
    final qualified = _qualifiedIndustries();
    final isTruncated = isDesktop && qualified.length > _desktopMaxItems;
    final hintStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      fontSize: DesignTokens.fontSizeXs,
    );
    final changePct = indexChangePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap（非 Row）：標題＋提示＋等權口徑＋大盤錨點項目較多，
        // 窄螢幕（手機）避免 RenderFlex overflow，寬螢幕視覺上仍呈單行。
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DesignTokens.spacing6,
          runSpacing: DesignTokens.spacing4,
          children: [
            Text(
              'marketOverview.industryPerformance'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 桌面模式有截斷時顯示提示
            if (isTruncated)
              Text(
                'marketOverview.industryTopBottom'.tr(
                  namedArgs: {'count': '${_desktopMaxItems ~/ 2}'},
                ),
                style: hintStyle,
              ),
            // 等權口徑標示（產業內個股簡單平均，非市值加權）
            Text('marketOverview.industryEqualWeighted'.tr(), style: hintStyle),
            // 大盤錨點：供對照產業普遍表現 vs 大盤本身
            if (changePct != null) ...[
              Text('marketOverview.industryIndexAnchor'.tr(), style: hintStyle),
              Text(
                IndustryPerformanceRow.formatSignedPct(changePct, 2),
                style: hintStyle?.copyWith(
                  color: context.priceColor(
                    IndustryPerformanceRow.roundForDisplay(changePct, 2),
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: DesignTokens.spacing10),
        if (isDesktop)
          _desktopGrid(_desktopItems(qualified))
        else
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: industries.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: DesignTokens.spacing8),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 120,
                  child: _IndustryCard(industry: industries[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 進榜資格：個股數 ≥ [kIndustryBoardMinStockCount] 才可能進入桌面前/後榜
  /// （手機水平捲動列表不受此限制，維持完整排名以保留脈絡）。
  List<IndustrySummary> _qualifiedIndustries() => industries
      .where((i) => i.stockCount >= kIndustryBoardMinStockCount)
      .toList();

  /// 桌面模式取 top + bottom 產業（已按 avgChangePct DESC 排序，且僅從
  /// [_qualifiedIndustries] 篩選——未達門檻不足以取代 8 個榜位）
  List<IndustrySummary> _desktopItems(List<IndustrySummary> qualified) {
    if (qualified.length <= _desktopMaxItems) return qualified;
    // 取前半 + 後半，保持排序順序
    const half = _desktopMaxItems ~/ 2;
    final top = qualified.take(half).toList();
    final bottom = qualified.skip(qualified.length - half).toList();
    // 去重（如果列表很短可能重疊）
    final seen = <String>{};
    final result = <IndustrySummary>[];
    for (final item in [...top, ...bottom]) {
      if (seen.add(item.industry)) result.add(item);
    }
    return result;
  }

  /// 桌面：等寬欄位填滿整列（Row + Expanded，相容外層 [IntrinsicHeight]）。
  ///
  /// 不能用 LayoutBuilder — 它不支援 IntrinsicHeight 的 intrinsic 量測，放進
  /// 寬版雙欄（`_buildPairedRow` 的 IntrinsicHeight）會讓量測崩潰、sections
  /// 互相重疊。Row+Expanded 支援 intrinsics，安全。
  Widget _desktopGrid(List<IndustrySummary> items) {
    const gap = DesignTokens.spacing8;
    const cols = 4;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) cells.add(const SizedBox(width: gap));
        final idx = i + j;
        cells.add(
          Expanded(
            child: idx < items.length
                ? SizedBox(
                    height: _cardHeight,
                    child: _IndustryCard(industry: items[idx]),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
      );
    }
    return Column(children: rows);
  }
}

class _IndustryCard extends StatelessWidget {
  const _IndustryCard({required this.industry});

  final IndustrySummary industry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 與顯示文字同精度捨入後再判方向（避免 -0.004 顯示 0.00% 卻著跌色）
    final displayedPct = IndustryPerformanceRow.roundForDisplay(
      industry.avgChangePct,
      2,
    );
    final isUp = displayedPct > 0;
    final color = isUp
        ? AppTheme.upColor
        : displayedPct < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // 頂部色條（依漲跌方向）
          Container(height: 2, color: color),
          // 內容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacing10,
                DesignTokens.spacing6,
                DesignTokens.spacing10,
                DesignTokens.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    industry.industry,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        IndustryPerformanceRow.formatSignedPct(
                          industry.avgChangePct,
                          2,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing4),
                      // 漲/跌家數（帶 ▲▼ 標記）
                      // 用 Expanded + FittedBox 防止大數字溢出
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppTheme.upSymbol,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.upColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              Text(
                                '${industry.advance}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: DesignTokens.fontSizeXs,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                ' ${AppTheme.downSymbol}',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.downColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              Text(
                                '${industry.decline}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: DesignTokens.fontSizeXs,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              // 家數基底（▲N▼M · X檔）——等權平均對小樣本敏感，
                              // 標出成分股數供投資人自行判讀可信度
                              Text(
                                ' · ${'marketOverview.industryStockCount'.tr(namedArgs: {'count': '${industry.stockCount}'})}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fontSize: DesignTokens.fontSizeXs,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 5 日動能（資料不足時 momentum5d 為 null，隱藏不顯示）
                  if (industry.momentum5d != null)
                    Text(
                      '${'marketOverview.industryMomentum5d'.tr()} '
                      '${IndustryPerformanceRow.formatSignedPct(industry.momentum5d!, 1)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.priceColor(
                          IndustryPerformanceRow.roundForDisplay(
                            industry.momentum5d!,
                            1,
                          ),
                        ),
                        fontSize: DesignTokens.fontSizeXs,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
