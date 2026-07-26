// 籌碼異動：標題不得替各區塊宣稱時間，時間語意須住在各區塊副標
//
// 實機（2026-07-27 看，資料日 2026-07-24）：上櫃面板標題寫「今日偵測到
// 10 項異常訊號」，其中 5 項是內部人轉讓，實際申報日是 07-20 ~ 07-23，
// **沒有一筆是 07-24**。
//
// 根因是同一句「今日」套在三種不同語意的 detector 上：
//
//   事件·當日   _detectInstitutionalSurge / _detectShortSurge
//               （皆已於 b66b6de / 891960e 加上 `date = ?`）
//   事件·近期窗 _detectInsiderTransfers（report_date >= 資料日 - 30 日）
//   狀態        _detectHighPledge（比較最新兩筆 insider_holding 快照；
//               實測全表只有 07-20 與 07-15 兩個快照日 → 觸發時依據的是
//               四天前的資料）
//               _detectForeignNearLimit（持股比 >= 上限 × 90%，是持續
//               狀態而非當日事件；實測目前 0 檔符合，該區從不出現）
//
// 不能把窗都收成當日：內部人申報全市場 30 天只有 9 筆（0.3 筆/日），
// 收成當日等於該區永遠空白；而「外資逼近上限」根本不是事件，沒有當日可言。
// 也不宜逐列標日期：值欄位已放了股數與筆數（見 4c50b40），再塞會過擠，
// 且對狀態類 detector 標日期沒有意義。
//
// 因此：標題不再宣稱時間，時間語意放進每個區塊本來就有的那一行副標。
// 純 i18n，零行為變更。
//
// 這條單獨看是打磨而非 bug（沒有人會因為「今日」二字做錯交易決策）。
// 修它的理由是同一個病在這輪反覆出現——文案宣稱一件事、資料是另一件事
// （跌 7% 顯示成漲幅／偏多 vs 訊號中性／訊號強度 60% vs 強度偏弱），
// 累積起來會讓使用者學會不相信畫面上的字。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 每個區塊副標各自須帶的時間語意標記。
  /// 刻意用「實際會出現在文案裡的詞」而非泛用時間詞，避免清單過寬而假綠。
  const timeMarkers = <String, List<String>>{
    'zh-TW': ['當日', '單日', '近 30 日', '最新', '現況'],
    'en': ['single-day', '30 days', 'latest', 'current'],
  };

  const subtitleKeys = [
    'subtitleInstitutionalSurge',
    'subtitleShortSurge',
    'subtitleInsiderTransfer',
    'subtitleHighPledge',
    'subtitleForeignNearLimit',
  ];

  /// 標題不得出現的時間宣稱
  const timeClaims = <String, List<String>>{
    'zh-TW': ['今日', '本日', '當日'],
    'en': ['today', 'daily'],
  };

  Map<String, dynamic> chipAnomalyCopy(String locale) {
    final root =
        json.decode(File('assets/translations/$locale.json').readAsStringSync())
            as Map<String, dynamic>;
    return (root['marketOverview'] as Map<String, dynamic>)['chipAnomaly']
        as Map<String, dynamic>;
  }

  for (final locale in timeMarkers.keys) {
    group('$locale：籌碼異動時間語意', () {
      test('🚨 標題不得宣稱時間（它涵蓋三種不同時間語意的 detector）', () {
        final summary = (chipAnomalyCopy(locale)['summary'] as String)
            .toLowerCase();
        final offenders = [
          for (final claim in timeClaims[locale]!)
            if (summary.contains(claim.toLowerCase())) claim,
        ];

        expect(
          offenders,
          isEmpty,
          reason:
              '同一句時間宣稱套在「當日事件」「近 30 日事件」「持續狀態」三種語意上；'
              '實測上櫃面板 10 項裡 5 項是 1~4 天前的內部人申報',
        );
      });

      test('🚨 每個區塊副標都要自帶時間語意', () {
        final copy = chipAnomalyCopy(locale);
        final missing = <String>[
          for (final key in subtitleKeys)
            if (!timeMarkers[locale]!.any(
              (m) =>
                  (copy[key] as String).toLowerCase().contains(m.toLowerCase()),
            ))
              '$key → ${copy[key]}',
        ];

        expect(
          missing,
          isEmpty,
          reason: '標題不再講時間後，時間語意必須落在區塊層級，否則使用者無從判斷這筆是哪個時段的',
        );
      });

      test('控制組：時間標記清單不得寬到連無時間語意的字串都命中', () {
        final copy = chipAnomalyCopy(locale);
        for (final key in ['title', 'highPledge', 'insiderTransfer']) {
          expect(
            timeMarkers[locale]!.any(
              (m) =>
                  (copy[key] as String).toLowerCase().contains(m.toLowerCase()),
            ),
            isFalse,
            reason: '$key（「${copy[key]}」）沒有時間語意；若清單連它都命中，上面那條測試就是假綠',
          );
        }
      });
    });
  }
}
