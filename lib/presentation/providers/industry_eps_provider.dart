import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/models/tpex/tpex_industry_eps.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// 產業 EPS 狀態
// ==================================================

/// 產業別 EPS 排名狀態
///
/// TODO: 加入 fetchedAt 欄位，讓 UI 顯示資料擷取時間
class IndustryEpsState {
  const IndustryEpsState({
    this.allData = const [],
    this.isLoading = false,
    this.error,
    this.selectedIndustry,
  });

  final List<TpexIndustryEps> allData;
  final bool isLoading;
  final String? error;
  final String? selectedIndustry;

  /// 所有可選的產業列表
  List<String> get industries {
    final set = <String>{};
    for (final d in allData) {
      if (d.industry.isNotEmpty) set.add(d.industry);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 篩選後的資料（依 EPS 降序排列）
  List<TpexIndustryEps> get filteredData {
    var data = allData;
    if (selectedIndustry != null) {
      data = data.where((d) => d.industry == selectedIndustry).toList();
    }
    return data..sort((a, b) => b.eps.compareTo(a.eps));
  }

  /// 季別標示
  String get quarterLabel {
    if (allData.isEmpty) return '';
    final first = allData.first;
    return '${first.year} Q${first.quarter}';
  }

  IndustryEpsState copyWith({
    List<TpexIndustryEps>? allData,
    bool? isLoading,
    String? error,
    Object? selectedIndustry = _sentinel,
  }) {
    return IndustryEpsState(
      allData: allData ?? this.allData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedIndustry: selectedIndustry == _sentinel
          ? this.selectedIndustry
          : selectedIndustry as String?,
    );
  }
}

const _sentinel = Object();

// ==================================================
// 產業 EPS Notifier
// ==================================================

class IndustryEpsNotifier extends Notifier<IndustryEpsState> {
  @override
  IndustryEpsState build() => const IndustryEpsState();

  /// 從 TPEX API 載入產業 EPS 資料
  Future<void> loadData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final tpex = ref.read(tpexClientProvider);
      final data = await tpex.getIndustryEps();

      state = state.copyWith(allData: data, isLoading: false);
    } catch (e) {
      AppLogger.warning('IndustryEpsNotifier', '載入產業 EPS 失敗', e);
      state = state.copyWith(error: ErrorDisplay.message(e), isLoading: false);
    }
  }

  /// 設定產業篩選（null = 全部）
  void setIndustryFilter(String? industry) {
    state = state.copyWith(selectedIndustry: industry);
  }

  /// 清除錯誤訊息（用於關閉錯誤 banner）
  void clearError() => state = state.copyWith(error: null);
}

// ==================================================
// Provider
// ==================================================

final industryEpsProvider =
    NotifierProvider<IndustryEpsNotifier, IndustryEpsState>(
      IndustryEpsNotifier.new,
    );
