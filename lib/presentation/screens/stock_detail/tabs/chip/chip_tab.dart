import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/day_trading_section.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/shareholding_section.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/distribution_section.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/insider_section.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/institutional_section.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/margin_trading_section.dart';

/// Comprehensive chip (籌碼) analysis tab with 7 sections.
class ChipTab extends ConsumerStatefulWidget {
  const ChipTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<ChipTab> createState() => _ChipTabState();
}

class _ChipTabState extends ConsumerState<ChipTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadChipData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chip = ref.watch(
      stockDetailProvider(widget.symbol).select((s) => s.chip),
    );
    final isLoadingChip = ref.watch(
      stockDetailProvider(widget.symbol).select((s) => s.loading.isLoadingChip),
    );

    if (isLoadingChip && chip.chipStrength == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Chip strength indicator
          if (chip.chipStrength != null)
            ChipStrengthIndicator(strength: chip.chipStrength!),

          if (chip.chipStrength != null) const SizedBox(height: 20),

          // 2. Institutional flow section
          InstitutionalSection(history: chip.institutionalHistory),

          const SizedBox(height: 24),

          // 3. Foreign shareholding section
          ShareholdingSection(history: chip.shareholdingHistory),

          const SizedBox(height: 24),

          // 4. Margin trading section
          MarginTradingSection(history: chip.marginTradingHistory),

          const SizedBox(height: 24),

          // 5. Day trading section
          DayTradingSection(history: chip.dayTradingHistory),

          const SizedBox(height: 24),

          // 6. Holding distribution section
          DistributionSection(distribution: chip.holdingDistribution),

          const SizedBox(height: 24),

          // 7. Insider holding section
          InsiderSection(history: chip.insiderHistory),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
