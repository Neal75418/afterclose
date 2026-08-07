import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/domain/services/alert/intraday_poll_schedule.dart';

/// 盤中輪詢排程(2026-08-07 設計、2026-08-08 實作)。
///
/// 三段升頻的核心決策:**現在該不該打 API**。
/// 高頻檢查會製造 v3.3「收盤才定案」本來要濾掉的噪音,所以沒掛條件時
/// 只在四個決策時刻檢查;掛了條件才升 5 分鐘;觸價後才升 1 分鐘。
void main() {
  DateTime at(int h, int m, {int day = 7}) => DateTime(2026, 8, day, h, m);

  group('交易時段', () {
    test('09:00–13:30 之間為盤中', () {
      expect(IntradayPollSchedule.isMarketHours(at(9, 0)), isTrue);
      expect(IntradayPollSchedule.isMarketHours(at(11, 30)), isTrue);
      expect(IntradayPollSchedule.isMarketHours(at(13, 30)), isTrue);
    });

    test('盤前盤後不輪詢', () {
      expect(IntradayPollSchedule.isMarketHours(at(8, 59)), isFalse);
      expect(IntradayPollSchedule.isMarketHours(at(13, 31)), isFalse);
      expect(IntradayPollSchedule.isMarketHours(at(20, 0)), isFalse);
    });

    test('🚨 週末不輪詢(2026-08-08 為週六)', () {
      expect(IntradayPollSchedule.isMarketHours(at(10, 0, day: 8)), isFalse);
    });
  });

  group('三段升頻:下一次該等多久', () {
    test('有觸價待觀察 → 緊盯(1 分鐘)', () {
      expect(
        IntradayPollSchedule.nextInterval(armedCount: 3, watchingCount: 1),
        const Duration(minutes: 1),
      );
    });

    test('有掛條件但無觸價 → 5 分鐘', () {
      expect(
        IntradayPollSchedule.nextInterval(armedCount: 2, watchingCount: 0),
        const Duration(minutes: 5),
      );
    });

    test('🚨 完全沒掛條件 → 不輪詢(null),只走背景決策時刻', () {
      expect(
        IntradayPollSchedule.nextInterval(armedCount: 0, watchingCount: 0),
        isNull,
      );
    });
  });

  group('背景決策時刻(沒掛條件時仍檢查的四個點)', () {
    test('命中 09:15 / 11:00 / 13:00 / 13:25', () {
      for (final (h, m) in [(9, 15), (11, 0), (13, 0), (13, 25)]) {
        expect(
          IntradayPollSchedule.isCheckpoint(at(h, m)),
          isTrue,
          reason: '$h:$m 應為決策時刻',
        );
      }
    });

    test('非決策時刻不觸發', () {
      expect(IntradayPollSchedule.isCheckpoint(at(10, 0)), isFalse);
      expect(IntradayPollSchedule.isCheckpoint(at(13, 10)), isFalse);
    });

    test('決策時刻在非交易時段/週末一律不算', () {
      expect(IntradayPollSchedule.isCheckpoint(at(9, 15, day: 8)), isFalse);
    });
  });
}
