import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:afterclose/core/l10n/app_strings.dart';

// ==================================================
// 微光效果尺寸常數
// ==================================================

/// 常用的微光效果尺寸，確保 UI 一致性
abstract final class ShimmerDimensions {
  // 卡片間距與邊距
  static const cardMarginH = 16.0;
  static const cardMarginV = 8.0;
  static const cardPadding = 16.0;
  static const cardRadius = 16.0;

  // 股票卡片骨架
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

  // 詳情頁骨架
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

  // 新聞卡片骨架
  static const newsTitleHeight = 18.0;
  static const newsTitleWidth2 = 200.0;
  static const newsMetaWidth1 = 60.0;
  static const newsMetaWidth2 = 80.0;
  static const newsMetaHeight = 14.0;

  // 常用間距
  static const spacingXs = 4.0;
  static const spacingSm = 6.0;
  static const spacingMd = 8.0;
  static const spacingLg = 12.0;
  static const spacingXl = 16.0;
  static const spacingXxl = 24.0;
}

/// 淺色與深色主題的微光效果顏色
abstract final class ShimmerColors {
  static Color baseColor(bool isDark) =>
      isDark ? Colors.grey[800]! : Colors.grey[300]!;
  static Color highlightColor(bool isDark) =>
      isDark ? Colors.grey[700]! : Colors.grey[100]!;

  /// 骨架容器填充顏色，在兩種模式下都能提供良好的對比度
  static Color skeletonColor(bool isDark) =>
      isDark ? const Color(0xFF3A3A4A) : Colors.white;
}

// ==================================================
// 微光效果 Widget
// ==================================================

/// 股票清單的微光載入骨架
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

/// 單一股票卡片骨架
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
          // 前置圖示佔位符
          Container(
            width: ShimmerDimensions.iconSize,
            height: ShimmerDimensions.iconSize,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.iconRadius),
            ),
          ),
          const SizedBox(width: ShimmerDimensions.spacingLg),
          // 內容區域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 股票代碼
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
                // 股票名稱
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
                // 標籤
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
          // 價格區域
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

/// 通用微光效果容器，用於自訂形狀
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

  /// 可選的無障礙語意標籤
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

/// 股票詳情頁的微光載入骨架
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
              // 標題列
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
              // 趨勢標籤
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
              // 區塊標題
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
              // 卡片
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
              // 區塊標題
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
              // 卡片們
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

/// 新聞清單的微光載入骨架
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

/// 單一新聞卡片骨架
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
          // 標題第 1 行
          Container(
            width: double.infinity,
            height: ShimmerDimensions.newsTitleHeight,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: ShimmerDimensions.spacingMd),
          // 標題第 2 行
          Container(
            width: ShimmerDimensions.newsTitleWidth2,
            height: ShimmerDimensions.newsTitleHeight,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(ShimmerDimensions.spacingXs),
            ),
          ),
          const SizedBox(height: ShimmerDimensions.spacingLg),
          // 元資訊
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
