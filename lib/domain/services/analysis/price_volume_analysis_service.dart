import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis/support_resistance_service.dart';

/// 價量分析服務
///
/// 負責分析價格與成交量的關係，檢測價量背離、
/// 高檔爆量、低檔縮量等價量訊號
class PriceVolumeAnalysisService {
  PriceVolumeAnalysisService({SupportResistanceService? srService})
    : _srService = srService ?? SupportResistanceService();

  final SupportResistanceService _srService;

  /// 分析價量關係以偵測背離
  ///
  /// 回傳包含背離狀態和上下文的 [PriceVolumeAnalysis]
  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = _lastN(prices, lookback + 1);

    // 計算價格變化
    final todayClose = recentPrices.first.close;
    final startClose = recentPrices.last.close;
    if (todayClose == null || startClose == null || startClose <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final priceChangePercent = ((todayClose - startClose) / startClose) * 100;

    // 計算成交量變化
    final volumeChange = _calculateVolumeChange(prices, recentPrices, lookback);
    if (volumeChange == null) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    // 計算價格在 60 日區間中的位置
    final (rangeLow, rangeHigh) = _srService.findRange(prices);
    double? pricePosition;
    if (rangeLow != null && rangeHigh != null && rangeHigh > rangeLow) {
      pricePosition = (todayClose - rangeLow) / (rangeHigh - rangeLow);
    }

    // 判斷背離狀態
    final state = _classifyPriceVolumeState(
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChange,
      pricePosition: pricePosition,
    );

    return PriceVolumeAnalysis(
      state: state,
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChange,
      pricePosition: pricePosition,
    );
  }

  // ==========================================
  // 私有輔助方法
  // ==========================================

  /// 計算成交量變化百分比
  ///
  /// 比較近期和前期的平均成交量，回傳變化百分比。
  /// 資料不足時回傳 null。
  double? _calculateVolumeChange(
    List<DailyPriceEntry> allPrices,
    List<DailyPriceEntry> recentPrices,
    int lookback,
  ) {
    final recentVolumes = recentPrices
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.length < lookback ~/ 2) return null;

    final avgRecentVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    final prevVolumes = _lastN(
      allPrices,
      lookback,
      skip: lookback,
    ).map((p) => p.volume ?? 0.0).where((v) => v > 0).toList();

    if (prevVolumes.isEmpty) return null;

    final avgPrevVolume =
        prevVolumes.reduce((a, b) => a + b) / prevVolumes.length;
    if (avgPrevVolume <= 0) return null;

    return ((avgRecentVolume - avgPrevVolume) / avgPrevVolume) * 100;
  }

  /// 依據價量變化與價格位置判斷背離狀態
  PriceVolumeState _classifyPriceVolumeState({
    required double priceChangePercent,
    required double volumeChangePercent,
    double? pricePosition,
  }) {
    const priceThreshold = RuleParams.priceVolumePriceThreshold;
    const volumeThreshold = RuleParams.priceVolumeVolumeThreshold;

    // 價漲量縮 = 多頭背離（警訊）
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      return PriceVolumeState.bullishDivergence;
    }
    // 價跌量增 = 空頭背離（恐慌）
    if (priceChangePercent <= -priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      return PriceVolumeState.bearishDivergence;
    }
    // 高檔爆量 = 可能出貨
    if (pricePosition != null &&
        pricePosition >= RuleParams.highPositionThreshold &&
        volumeChangePercent >=
            volumeThreshold * RuleParams.highVolumeMultiplier) {
      return PriceVolumeState.highVolumeAtHigh;
    }
    // 低檔縮量 = 可能吸籌
    if (pricePosition != null &&
        pricePosition <= RuleParams.lowPositionThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      return PriceVolumeState.lowVolumeAtLow;
    }
    // 健康：價漲量增
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      return PriceVolumeState.healthyUptrend;
    }

    return PriceVolumeState.neutral;
  }

  /// 從列表尾端取得 [count] 個元素（反序：最新在前），
  /// 可選跳過尾端 [skip] 個元素。
  static List<T> _lastN<T>(List<T> list, int count, {int skip = 0}) {
    final end = (list.length - skip).clamp(0, list.length);
    final start = (end - count).clamp(0, end);
    return list.sublist(start, end).reversed.toList();
  }
}
