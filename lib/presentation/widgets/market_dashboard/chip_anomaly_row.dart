import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/chip_anomaly_service.dart'
    show ChipAnomaly, ChipAnomalyType, ChipSeverity, kZeroInsiderTransfer;

/// 籌碼異動摘要列
///
/// 台股風格：摘要橫幅 + 各類型直接展開（最多顯示 3 檔），
/// 每檔附白話一行說明。支援點擊個股導航至詳情頁。
class ChipAnomalyRow extends StatelessWidget {
  const ChipAnomalyRow({super.key, required this.anomalies, this.onStockTap});

  final List<ChipAnomaly> anomalies;

  /// 點擊個股時的回呼，傳入股票代號。由父層決定導航行為。
  final void Function(String symbol)? onStockTap;

  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // 依類型分群
    final grouped = <ChipAnomalyType, List<ChipAnomaly>>{};
    for (final a in anomalies) {
      grouped.putIfAbsent(a.type, () => []).add(a);
    }

    // 依嚴重度排序（使用 index 比較，保留擴充彈性）
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) {
        final sa = grouped[a]!.first.severity;
        final sb = grouped[b]!.first.severity;
        if (sa == sb) return a.index.compareTo(b.index);
        return sa.index.compareTo(sb.index);
      });

    final hasHigh = anomalies.any((a) => a.severity == ChipSeverity.high);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.chipAnomaly.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DesignTokens.spacing8),

        // 摘要橫幅
        _SummaryBanner(count: anomalies.length, hasHigh: hasHigh),
        const SizedBox(height: DesignTokens.spacing12),

        // 各類型區塊（直接展開，不折疊）
        for (int i = 0; i < sortedTypes.length; i++) ...[
          if (i > 0) const SizedBox(height: DesignTokens.spacing8),
          _AnomalyTypeSection(
            type: sortedTypes[i],
            items: grouped[sortedTypes[i]]!.take(3).toList(),
            totalCount: grouped[sortedTypes[i]]!.length,
            onStockTap: onStockTap,
          ),
        ],
      ],
    );
  }
}

// ==================================================
// 摘要橫幅
// ==================================================

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.count, required this.hasHigh});

  final int count;
  final bool hasHigh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasHigh ? AppTheme.downColor : Colors.orange;
    final label = 'marketOverview.chipAnomaly.summary'.tr(
      namedArgs: {'count': count.toString()},
    );

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing12,
          vertical: DesignTokens.spacing8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: DesignTokens.iconSizeSm,
              color: color,
            ),
            const SizedBox(width: DesignTokens.spacing6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// 單一類型區塊
// ==================================================

class _AnomalyTypeSection extends StatelessWidget {
  const _AnomalyTypeSection({
    required this.type,
    required this.items,
    required this.totalCount,
    this.onStockTap,
  });

  final ChipAnomalyType type;

  /// 顯示的個股（最多 3 筆）
  final List<ChipAnomaly> items;

  /// 實際偵測到的總筆數（偵測上限 5 筆）
  final int totalCount;

  final void Function(String symbol)? onStockTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _typeMeta(type);
    final isHigh = items.any((a) => a.severity == ChipSeverity.high);
    final accentColor = isHigh ? AppTheme.downColor : Colors.orange;
    final hiddenCount = totalCount - items.length;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing12,
          vertical: DesignTokens.spacing8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 類型標頭：icon + 名稱 + 實際總數徽章
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Icon(
                    meta.icon,
                    size: DesignTokens.iconSizeSm,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Text(
                  meta.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing6),
                // 顯示實際偵測總數
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    '$totalCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: DesignTokens.fontSizeXs,
                    ),
                  ),
                ),
              ],
            ),

            // 副標題（白話說明）
            const SizedBox(height: DesignTokens.spacing2),
            Text(
              meta.subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),

            // 個股列表
            const SizedBox(height: DesignTokens.spacing6),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: DesignTokens.spacing4),
            for (final item in items)
              _AnomalyItem(anomaly: item, onTap: onStockTap),

            // 「還有 N 檔未顯示」提示
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.spacing4),
                child: Text(
                  'marketOverview.chipAnomaly.moreItems'.tr(
                    namedArgs: {'count': hiddenCount.toString()},
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: DesignTokens.fontSizeXs,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// 單檔股票列
// ==================================================

class _AnomalyItem extends StatelessWidget {
  const _AnomalyItem({required this.anomaly, this.onTap});

  final ChipAnomaly anomaly;
  final void Function(String symbol)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = anomaly.severity == ChipSeverity.high
        ? AppTheme.downColor
        : Colors.orange;
    final description = _buildDescription(anomaly);

    return MergeSemantics(
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!(anomaly.symbol);
              }
            : null,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 代號 + 名稱 + 關鍵數值
              Row(
                children: [
                  Text(
                    anomaly.symbol,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing6),
                  Expanded(
                    child: Text(
                      anomaly.stockName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (anomaly.keyValue != null)
                    Text(
                      anomaly.keyValue!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),

              // 白話一行說明
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.spacing2),
                  child: Text(
                    description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: DesignTokens.fontSizeXs,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// 白話描述（走 i18n）
// ==================================================

String? _buildDescription(ChipAnomaly a) {
  final v = a.keyValue;
  if (v == null) return null;

  const base = 'marketOverview.chipAnomaly.desc';

  switch (a.type) {
    case ChipAnomalyType.highPledge:
      return '$base.highPledge'.tr(namedArgs: {'value': v});

    case ChipAnomalyType.insiderTransfer:
      if (v == kZeroInsiderTransfer) return '$base.insiderTransferZero'.tr();
      return '$base.insiderTransfer'.tr(namedArgs: {'value': v});

    case ChipAnomalyType.foreignNearLimit:
      return '$base.foreignNearLimit'.tr(namedArgs: {'value': v});

    case ChipAnomalyType.shortSurge:
      return '$base.shortSurge'.tr(namedArgs: {'value': v});

    case ChipAnomalyType.institutionalSurge:
      if (v.startsWith('+')) {
        return '$base.instBuy'.tr(namedArgs: {'value': v.substring(1)});
      }
      if (v.startsWith('-')) {
        return '$base.instSell'.tr(namedArgs: {'value': v.substring(1)});
      }
      return '$base.instMove'.tr(namedArgs: {'value': v});
  }
}

// ==================================================
// 類型 metadata
// ==================================================

class _TypeMeta {
  const _TypeMeta({
    required this.icon,
    required this.label,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String subtitle;
}

_TypeMeta _typeMeta(ChipAnomalyType type) {
  switch (type) {
    case ChipAnomalyType.highPledge:
      return _TypeMeta(
        icon: Icons.lock_outline_rounded,
        label: 'marketOverview.chipAnomaly.highPledge'.tr(),
        subtitle: 'marketOverview.chipAnomaly.subtitleHighPledge'.tr(),
      );
    case ChipAnomalyType.insiderTransfer:
      return _TypeMeta(
        icon: Icons.swap_horiz_rounded,
        label: 'marketOverview.chipAnomaly.insiderTransfer'.tr(),
        subtitle: 'marketOverview.chipAnomaly.subtitleInsiderTransfer'.tr(),
      );
    case ChipAnomalyType.foreignNearLimit:
      return _TypeMeta(
        icon: Icons.flag_rounded,
        label: 'marketOverview.chipAnomaly.foreignNearLimit'.tr(),
        subtitle: 'marketOverview.chipAnomaly.subtitleForeignNearLimit'.tr(),
      );
    case ChipAnomalyType.shortSurge:
      return _TypeMeta(
        icon: Icons.trending_down_rounded,
        label: 'marketOverview.chipAnomaly.shortSurge'.tr(),
        subtitle: 'marketOverview.chipAnomaly.subtitleShortSurge'.tr(),
      );
    case ChipAnomalyType.institutionalSurge:
      return _TypeMeta(
        icon: Icons.flash_on_rounded,
        label: 'marketOverview.chipAnomaly.institutionalSurge'.tr(),
        subtitle: 'marketOverview.chipAnomaly.subtitleInstitutionalSurge'.tr(),
      );
  }
}
