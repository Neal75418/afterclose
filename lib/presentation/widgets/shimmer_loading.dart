import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:afterclose/core/l10n/app_strings.dart';

// ==================================================
// Shimmer Dimension Constants
// ==================================================

/// Common shimmer dimensions for consistent UI
abstract final class ShimmerDimensions {
  // Card padding and margin
  static const cardMarginH = 16.0;
  static const cardMarginV = 8.0;
  static const cardPadding = 16.0;
  static const cardRadius = 16.0;

  // Stock card skeleton
  static const iconSize = 48.0;
  static const iconRadius = 12.0;
  static const symbolWidth = 80.0;
  static const symbolHeight = 18.0;
  static const nameWidth = 120.0;
  static const nameHeight = 14.0;
  static const tagWidth1 = 50.0;
  static const tagWidth2 = 60.0;
  static const tagHeight = 20.0;
  static const tagRadius = 10.0;
  static const priceWidth = 70.0;
  static const priceHeight = 20.0;
  static const changeWidth = 50.0;
  static const changeHeight = 16.0;

  // Detail page skeleton
  static const headerTitleWidth = 150.0;
  static const headerTitleHeight = 28.0;
  static const headerSubWidth = 80.0;
  static const headerSubHeight = 20.0;
  static const headerPriceWidth = 100.0;
  static const headerPriceHeight = 32.0;
  static const headerChangeWidth = 70.0;
  static const headerChangeHeight = 24.0;
  static const chipWidth = 100.0;
  static const chipHeight = 48.0;
  static const sectionTitleWidth = 80.0;
  static const sectionTitleHeight = 20.0;
  static const cardHeight = 100.0;
  static const listItemHeight = 72.0;

  // News card skeleton
  static const newsTitleHeight = 18.0;
  static const newsTitleWidth2 = 200.0;
  static const newsMetaWidth1 = 60.0;
  static const newsMetaWidth2 = 80.0;
  static const newsMetaHeight = 14.0;

  // Common spacing
  static const spacingXs = 4.0;
  static const spacingSm = 6.0;
  static const spacingMd = 8.0;
  static const spacingLg = 12.0;
  static const spacingXl = 16.0;
  static const spacingXxl = 24.0;
}

/// Shimmer colors for light and dark themes
abstract final class ShimmerColors {
  static Color baseColor(bool isDark) =>
      isDark ? Colors.grey[800]! : Colors.grey[300]!;
  static Color highlightColor(bool isDark) =>
      isDark ? Colors.grey[700]! : Colors.grey[100]!;

  /// Skeleton container fill color - provides good contrast in both modes
  static Color skeletonColor(bool isDark) =>
      isDark ? const Color(0xFF3A3A4A) : Colors.white;
}

// ==================================================
// Shimmer Widgets
// ==================================================

/// Shimmer loading skeleton for stock list
class StockListShimmer extends StatelessWidget {
  const StockListShimmer({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: S.shimmerLoadingStockList,
      excludeSemantics: true,
      child: Shimmer.fromColors(
        baseColor: ShimmerColors.baseColor(isDark),
        highlightColor: ShimmerColors.highlightColor(isDark),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          itemBuilder: (context, index) => _StockCardSkeleton(isDark: isDark),
        ),
      ),
    );
  }
}

/// Single stock card skeleton
class _StockCardSkeleton extends StatelessWidget {
  const _StockCardSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final skeletonColor = ShimmerColors.skeletonColor(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: ShimmerDimensions.cardMarginH,
        vertical: ShimmerDimensions.cardMarginV,
      ),
      padding: const EdgeInsets.all(ShimmerDimensions.cardPadding),
      decoration: BoxDecoration(
        color: skeletonColor,
        borderRadius: BorderRadius.circular(ShimmerDimensions.cardRadius),
      ),
      child: Row(
        children: [
          // Leading icon placeholder
          Container(
            width: ShimmerDimensions.iconSize,
            height: ShimmerDimensions.iconSize,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.iconRadius),
            ),
          ),
          const SizedBox(width: ShimmerDimensions.spacingLg),
          // Content area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Symbol
                Container(
                  width: ShimmerDimensions.symbolWidth,
                  height: ShimmerDimensions.symbolHeight,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(
                      ShimmerDimensions.spacingXs,
                    ),
                  ),
                ),
                const SizedBox(height: ShimmerDimensions.spacingMd),
                // Name
                Container(
                  width: ShimmerDimensions.nameWidth,
                  height: ShimmerDimensions.nameHeight,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(
                      ShimmerDimensions.spacingXs,
                    ),
                  ),
                ),
                const SizedBox(height: ShimmerDimensions.spacingMd),
                // Tags
                Row(
                  children: [
                    Container(
                      width: ShimmerDimensions.tagWidth1,
                      height: ShimmerDimensions.tagHeight,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          ShimmerDimensions.tagRadius,
                        ),
                      ),
                    ),
                    const SizedBox(width: ShimmerDimensions.spacingMd),
                    Container(
                      width: ShimmerDimensions.tagWidth2,
                      height: ShimmerDimensions.tagHeight,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          ShimmerDimensions.tagRadius,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Price area
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: ShimmerDimensions.priceWidth,
                height: ShimmerDimensions.priceHeight,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(
                    ShimmerDimensions.spacingXs,
                  ),
                ),
              ),
              const SizedBox(height: ShimmerDimensions.spacingSm),
              Container(
                width: ShimmerDimensions.changeWidth,
                height: ShimmerDimensions.changeHeight,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(
                    ShimmerDimensions.spacingXs,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Generic shimmer container for custom shapes
class ShimmerContainer extends StatelessWidget {
  const ShimmerContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.semanticLabel,
  });

  final double width;
  final double height;
  final double borderRadius;

  /// Optional semantic label for accessibility
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shimmer = Shimmer.fromColors(
      baseColor: ShimmerColors.baseColor(isDark),
      highlightColor: ShimmerColors.highlightColor(isDark),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ShimmerColors.skeletonColor(isDark),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: shimmer,
      );
    }

    return shimmer;
  }
}

/// Shimmer loading skeleton for stock detail page
class StockDetailShimmer extends StatelessWidget {
  const StockDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = ShimmerColors.skeletonColor(isDark);

    return Semantics(
      label: S.shimmerLoadingStockDetail,
      excludeSemantics: true,
      child: Shimmer.fromColors(
        baseColor: ShimmerColors.baseColor(isDark),
        highlightColor: ShimmerColors.highlightColor(isDark),
        child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ShimmerDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: ShimmerDimensions.headerTitleWidth,
                        height: ShimmerDimensions.headerTitleHeight,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(
                            ShimmerDimensions.spacingSm,
                          ),
                        ),
                      ),
                      const SizedBox(height: ShimmerDimensions.spacingMd),
                      Container(
                        width: ShimmerDimensions.headerSubWidth,
                        height: ShimmerDimensions.headerSubHeight,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(
                            ShimmerDimensions.spacingXs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: ShimmerDimensions.headerPriceWidth,
                      height: ShimmerDimensions.headerPriceHeight,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          ShimmerDimensions.spacingSm,
                        ),
                      ),
                    ),
                    const SizedBox(height: ShimmerDimensions.spacingMd),
                    Container(
                      width: ShimmerDimensions.headerChangeWidth,
                      height: ShimmerDimensions.headerChangeHeight,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          ShimmerDimensions.spacingXs,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: ShimmerDimensions.spacingXxl),
            // Trend chips
            Row(
              children: [
                Container(
                  width: ShimmerDimensions.chipWidth,
                  height: ShimmerDimensions.chipHeight,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(
                      ShimmerDimensions.spacingMd,
                    ),
                  ),
                ),
                const SizedBox(width: ShimmerDimensions.spacingMd),
                Container(
                  width: ShimmerDimensions.chipWidth,
                  height: ShimmerDimensions.chipHeight,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(
                      ShimmerDimensions.spacingMd,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ShimmerDimensions.spacingXxl),
            // Section title
            Container(
              width: ShimmerDimensions.sectionTitleWidth,
              height: ShimmerDimensions.sectionTitleHeight,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(
                  ShimmerDimensions.spacingXs,
                ),
              ),
            ),
            const SizedBox(height: ShimmerDimensions.spacingLg),
            // Card
            Container(
              width: double.infinity,
              height: ShimmerDimensions.cardHeight,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(
                  ShimmerDimensions.cardRadius,
                ),
              ),
            ),
            const SizedBox(height: ShimmerDimensions.spacingXxl),
            // Section title
            Container(
              width: ShimmerDimensions.sectionTitleWidth,
              height: ShimmerDimensions.sectionTitleHeight,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(
                  ShimmerDimensions.spacingXs,
                ),
              ),
            ),
            const SizedBox(height: ShimmerDimensions.spacingLg),
            // Cards
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(
                  bottom: ShimmerDimensions.spacingMd,
                ),
                child: Container(
                  width: double.infinity,
                  height: ShimmerDimensions.listItemHeight,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(
                      ShimmerDimensions.cardRadius,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for news list
class NewsListShimmer extends StatelessWidget {
  const NewsListShimmer({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: S.shimmerLoadingNewsList,
      excludeSemantics: true,
      child: Shimmer.fromColors(
        baseColor: ShimmerColors.baseColor(isDark),
        highlightColor: ShimmerColors.highlightColor(isDark),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          itemBuilder: (context, index) => _NewsCardSkeleton(isDark: isDark),
        ),
      ),
    );
  }
}

/// Single news card skeleton
class _NewsCardSkeleton extends StatelessWidget {
  const _NewsCardSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final skeletonColor = ShimmerColors.skeletonColor(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: ShimmerDimensions.cardMarginH,
        vertical: ShimmerDimensions.cardMarginV,
      ),
      padding: const EdgeInsets.all(ShimmerDimensions.cardPadding),
      decoration: BoxDecoration(
        color: skeletonColor,
        borderRadius: BorderRadius.circular(ShimmerDimensions.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title line 1
          Container(
            width: double.infinity,
            height: ShimmerDimensions.newsTitleHeight,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: ShimmerDimensions.spacingMd),
          // Title line 2
          Container(
            width: ShimmerDimensions.newsTitleWidth2,
            height: ShimmerDimensions.newsTitleHeight,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: ShimmerDimensions.spacingLg),
          // Meta info
          Row(
            children: [
              Container(
                width: ShimmerDimensions.newsMetaWidth1,
                height: ShimmerDimensions.newsMetaHeight,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(
                    ShimmerDimensions.spacingXs,
                  ),
                ),
              ),
              const SizedBox(width: ShimmerDimensions.spacingXl),
              Container(
                width: ShimmerDimensions.newsMetaWidth2,
                height: ShimmerDimensions.newsMetaHeight,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(
                    ShimmerDimensions.spacingXs,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
