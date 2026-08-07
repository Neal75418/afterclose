import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/models/twse/twse_material_info.dart';

void main() {
  group('investorConferenceDate 標準函式（供已存新聞重用）', () {
    test('含法說會標記＋斜線日期→開會日', () {
      expect(
        investorConferenceDate('受邀參加法人說明會\n召開法人說明會之日期：115/07/24'),
        DateTime(2026, 7, 24),
      );
    });
    test('非法說會→null', () {
      expect(investorConferenceDate('公告更名 115/07/24'), isNull);
    });
    test('法說會但無日期→null', () {
      expect(investorConferenceDate('受邀參加法人說明會'), isNull);
    });
  });

  group('TwseMaterialInfo.fromJson', () {
    test('解析中文鍵（含「主旨 」尾空格陷阱）並清理換行', () {
      final info = TwseMaterialInfo.fromJson({
        '發言日期': '1150723',
        '發言時間': '70003',
        '公司代號': '1721',
        '公司名稱': '三晃',
        '主旨 ': '公告本公司名稱\r\n更名',
        '符合條款': '第51款',
        '事實發生日': '1150629',
        '說明': '1.事實發生日：民國115年06月29日',
      });
      expect(info.code, '1721');
      expect(info.subject, '公告本公司名稱 更名');
      expect(info.speakDate, '1150723');
      expect(info.speakTime, '70003');
    });

    test('publishedAt：民國日期＋補零時間轉台北時間再存 UTC', () {
      final info = TwseMaterialInfo.fromJson({
        '發言日期': '1150723',
        '發言時間': '70003', // 07:00:03
        '公司代號': '1721',
        '公司名稱': '三晃',
        '主旨 ': 'x',
        '說明': '',
      });
      // 台北 07:00:03 = UTC 前一日 23:00:03
      expect(info.publishedAtUtc, DateTime.utc(2026, 7, 22, 23, 0, 3));
    });

    test('conferenceDate：從說明抽「召開法人說明會之日期」', () {
      final info = TwseMaterialInfo.fromJson({
        '發言日期': '1150723',
        '發言時間': '151812',
        '公司代號': '1537',
        '公司名稱': '廣隆',
        '主旨 ': '本公司受邀參加法人說明會',
        '說明': '1.召開法人說明會之日期：115/07/24\r\n2.召開法人說明會之時間：14 時',
      });
      expect(info.isInvestorConference, isTrue);
      expect(info.conferenceDate, DateTime(2026, 7, 24));
    });

    test('非法說會公告 conferenceDate 為 null', () {
      final info = TwseMaterialInfo.fromJson({
        '發言日期': '1150723',
        '發言時間': '70003',
        '公司代號': '1721',
        '公司名稱': '三晃',
        '主旨 ': '公告更名',
        '說明': '無相關',
      });
      expect(info.isInvestorConference, isFalse);
      expect(info.conferenceDate, isNull);
    });
  });
}
