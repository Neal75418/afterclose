// Stage 5c Commit 1 — global horizon state provider
//
// 驗證 [selectedHorizonProvider] 的預設值、寫入、以及 provider scope
// 隔離（一個 ProviderContainer 的變動不影響另一個）。
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/presentation/providers/selected_horizon_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectedHorizonProvider', () {
    test('defaults to Horizon.short on first read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedHorizonProvider), Horizon.short);
    });

    test('select() mutates and can be read back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedHorizonProvider.notifier).select(Horizon.long);

      expect(container.read(selectedHorizonProvider), Horizon.long);
    });

    test('two containers have independent state', () {
      final a = ProviderContainer();
      final b = ProviderContainer();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      a.read(selectedHorizonProvider.notifier).select(Horizon.long);

      // b 仍然是 default，證明 provider 沒有跨 container 洩漏
      expect(a.read(selectedHorizonProvider), Horizon.long);
      expect(b.read(selectedHorizonProvider), Horizon.short);
    });

    test('select() back to short reverts the value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(selectedHorizonProvider.notifier);
      notifier.select(Horizon.long);
      notifier.select(Horizon.short);

      expect(container.read(selectedHorizonProvider), Horizon.short);
    });
  });
}
