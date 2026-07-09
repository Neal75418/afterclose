import 'package:afterclose/presentation/providers/short_sell_ranking_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShortSellRankingState.copyWith', () {
    test('不帶 error 參數時保留現有錯誤（不得靜默清空）', () {
      const state = ShortSellRankingState(error: '網路錯誤');

      // 只更新其他欄位——error 未傳入，不應被清掉
      final updated = state.copyWith(isLoading: true);

      expect(updated.error, '網路錯誤');
      expect(updated.isLoading, isTrue);
    });

    test('顯式傳入 error: null 才清空錯誤', () {
      const state = ShortSellRankingState(error: '網路錯誤');

      final cleared = state.copyWith(error: null);

      expect(cleared.error, isNull);
    });

    test('傳入新 error 覆寫舊值', () {
      const state = ShortSellRankingState(error: '舊錯誤');

      expect(state.copyWith(error: '新錯誤').error, '新錯誤');
    });
  });
}
