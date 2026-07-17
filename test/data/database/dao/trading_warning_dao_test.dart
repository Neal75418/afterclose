import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  group('insertWarningData 同日更正', () {
    final date = DateTime(2026, 7, 17);

    test('同 (symbol,date,warningType) 重新同步時以新資料更新該列（不吞更正）', () async {
      // 第一次同步：處置股，結束日 07-20、原始說明
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: date,
          warningType: 'DISPOSAL',
          reasonDescription: const Value('原始處置原因'),
          disposalMeasures: const Value('人工管制'),
          disposalEndDate: Value(DateTime(2026, 7, 20)),
          isActive: const Value(true),
        ),
      ]);

      // 同日盤中更正：延長處置結束日至 07-30、修正說明與措施
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: date,
          warningType: 'DISPOSAL',
          reasonDescription: const Value('更正後處置原因'),
          disposalMeasures: const Value('分盤集合競價'),
          disposalEndDate: Value(DateTime(2026, 7, 30)),
          isActive: const Value(true),
        ),
      ]);

      final rows = await db.getActiveWarningsByType('DISPOSAL');
      expect(rows, hasLength(1));
      final row = rows.single;
      // insertOrIgnore 會保留第一筆 → 這些斷言在修正前會失敗
      expect(row.reasonDescription, '更正後處置原因');
      expect(row.disposalMeasures, '分盤集合競價');
      expect(row.disposalEndDate, DateTime(2026, 7, 30));
    });

    test('updateExpiredWarnings 仍能將已過期處置改為非生效（更新模式不會重複處理）', () async {
      // 模擬 insertOrReplace 以 isActive=true 重寫一筆結束日已過的處置
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: date,
          warningType: 'DISPOSAL',
          disposalEndDate: Value(DateTime(2026, 7, 15)),
          isActive: const Value(true),
        ),
      ]);

      // 每次 insertWarningData 後皆會呼叫、以 disposalEndDate vs now 重新推導 isActive
      final updated = await db.updateExpiredWarnings(
        now: DateTime(2026, 7, 18),
      );

      expect(updated, 1); // 有一列被改為非生效
      final active = await db.getActiveWarningsByType('DISPOSAL');
      expect(active, isEmpty); // 過期 → 不再生效，與插入模式無關
    });
  });
}
