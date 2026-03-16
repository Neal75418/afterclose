import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/data/models/tpex/tpex_industry_eps.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Industry EPS State
// ==================================================

/// 產業別 EPS 排名狀態
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
// Notifier
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
      state = state.copyWith(error: ErrorDisplay.message(e), isLoading: false);
    }
  }

  /// 設定產業篩選（null = 全部）
  void setIndustryFilter(String? industry) {
    state = state.copyWith(selectedIndustry: industry);
  }
}

// ==================================================
// Provider
// ==================================================

final industryEpsProvider =
    NotifierProvider<IndustryEpsNotifier, IndustryEpsState>(
      IndustryEpsNotifier.new,
    );
