// Integration tests for CalibrationCacheDaoMixin
//
// 用 in-memory Drift (`AppDatabase.forTesting`) 驗證六個 well-known keys
// 的讀寫 + atomic transaction 行為。

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/dao/calibration_cache_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('getCachedCalibration — empty states', () {
    test('fresh DB returns CachedCalibration.empty (all null)', () async {
      final cached = await db.getCachedCalibration();

      expect(cached.version, isNull);
      expect(cached.shortJson, isNull);
      expect(cached.longJson, isNull);
      expect(cached.shortHash, isNull);
      expect(cached.longHash, isNull);
      expect(cached.lastCheckedAt, isNull);
      expect(cached.hasCompleteContent, isFalse);
    });

    test(
      'existing unrelated app_settings do not pollute calibration',
      () async {
        // 模擬 FINMIND_TOKEN 已存在
        await db.setSetting('finmind.token', 'eyJ-test-token');

        final cached = await db.getCachedCalibration();

        expect(cached.version, isNull);
        expect(cached.shortJson, isNull);
        // FINMIND_TOKEN 仍然存在
        expect(await db.getSetting('finmind.token'), 'eyJ-test-token');
      },
    );
  });

  group('writeCalibration — happy path', () {
    test('round-trips all six fields atomically', () async {
      final checkedAt = DateTime.utc(2026, 4, 12, 10, 30);

      await db.writeCalibration(
        version: '2026-04-12',
        shortJson: '{"schema_version": 1, "rules": {}}',
        longJson: '{"schema_version": 1, "rules": {"a": {"score": 25}}}',
        shortHash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        longHash:
            'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',
        checkedAt: checkedAt,
      );

      final cached = await db.getCachedCalibration();

      expect(cached.version, '2026-04-12');
      expect(cached.shortJson, '{"schema_version": 1, "rules": {}}');
      expect(
        cached.longJson,
        '{"schema_version": 1, "rules": {"a": {"score": 25}}}',
      );
      expect(
        cached.shortHash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        cached.longHash,
        'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',
      );
      expect(cached.lastCheckedAt, checkedAt);
      expect(cached.hasCompleteContent, isTrue);
    });

    test('second write with new version overwrites all fields', () async {
      await db.writeCalibration(
        version: '2026-03-15',
        shortJson: '{"v1": true}',
        longJson: '{"v1": true}',
        shortHash: 'old_short_hash',
        longHash: 'old_long_hash',
        checkedAt: DateTime.utc(2026, 3, 15),
      );

      await db.writeCalibration(
        version: '2026-04-12',
        shortJson: '{"v2": true}',
        longJson: '{"v2": true}',
        shortHash: 'new_short_hash',
        longHash: 'new_long_hash',
        checkedAt: DateTime.utc(2026, 4, 12),
      );

      final cached = await db.getCachedCalibration();

      expect(cached.version, '2026-04-12');
      expect(cached.shortJson, '{"v2": true}');
      expect(cached.shortHash, 'new_short_hash');
      expect(cached.longHash, 'new_long_hash');
      expect(cached.lastCheckedAt, DateTime.utc(2026, 4, 12));
    });

    test('lastCheckedAt stored as UTC ISO 8601', () async {
      // 以本地時區 DateTime 傳入 — 內部應轉成 UTC 儲存
      final localNow = DateTime(2026, 4, 12, 18, 45);

      await db.writeCalibration(
        version: '2026-04-12',
        shortJson: '{}',
        longJson: '{}',
        shortHash: 'h1',
        longHash: 'h2',
        checkedAt: localNow,
      );

      final cached = await db.getCachedCalibration();

      // 還原後應等於原始時間點（DateTime 會有 UTC/local 標記，
      // 但 epoch millis 必須一致）
      expect(
        cached.lastCheckedAt!.millisecondsSinceEpoch,
        localNow.millisecondsSinceEpoch,
      );
    });
  });

  group('touchCalibrationLastCheckedAt', () {
    test('updates only lastCheckedAt without touching other fields', () async {
      // 先寫一組完整資料
      await db.writeCalibration(
        version: '2026-04-12',
        shortJson: '{"schema_version": 1, "rules": {}}',
        longJson: '{"schema_version": 1, "rules": {}}',
        shortHash: 'original_short',
        longHash: 'original_long',
        checkedAt: DateTime.utc(2026, 4, 12, 10, 0),
      );

      // 24h 後 touch（例如 UpToDate / PermanentFailure case）
      final newCheckedAt = DateTime.utc(2026, 4, 13, 10, 0);
      await db.touchCalibrationLastCheckedAt(newCheckedAt);

      final cached = await db.getCachedCalibration();

      // lastCheckedAt 更新
      expect(cached.lastCheckedAt, newCheckedAt);
      // 其他欄位維持原狀
      expect(cached.version, '2026-04-12');
      expect(cached.shortJson, '{"schema_version": 1, "rules": {}}');
      expect(cached.longJson, '{"schema_version": 1, "rules": {}}');
      expect(cached.shortHash, 'original_short');
      expect(cached.longHash, 'original_long');
    });

    test('can touch on empty cache (no prior write)', () async {
      final now = DateTime.utc(2026, 4, 12);
      await db.touchCalibrationLastCheckedAt(now);

      final cached = await db.getCachedCalibration();

      expect(cached.lastCheckedAt, now);
      expect(cached.version, isNull);
      expect(cached.shortJson, isNull);
      expect(cached.hasCompleteContent, isFalse);
    });
  });

  group('CachedCalibration.hasCompleteContent', () {
    test('requires version + shortJson + longJson all present', () {
      expect(
        const CachedCalibration(
          version: 'v1',
          shortJson: '{}',
          longJson: '{}',
        ).hasCompleteContent,
        isTrue,
      );

      expect(
        const CachedCalibration(
          shortJson: '{}',
          longJson: '{}',
        ).hasCompleteContent,
        isFalse,
        reason: 'version missing',
      );

      expect(
        const CachedCalibration(
          version: 'v1',
          longJson: '{}',
        ).hasCompleteContent,
        isFalse,
        reason: 'shortJson missing',
      );

      expect(
        const CachedCalibration(
          version: 'v1',
          shortJson: '{}',
        ).hasCompleteContent,
        isFalse,
        reason: 'longJson missing',
      );
    });

    test('empty constant has all nulls', () {
      expect(CachedCalibration.empty.version, isNull);
      expect(CachedCalibration.empty.shortJson, isNull);
      expect(CachedCalibration.empty.longJson, isNull);
      expect(CachedCalibration.empty.shortHash, isNull);
      expect(CachedCalibration.empty.longHash, isNull);
      expect(CachedCalibration.empty.lastCheckedAt, isNull);
      expect(CachedCalibration.empty.hasCompleteContent, isFalse);
    });
  });

  group('Graceful degradation — malformed lastCheckedAt', () {
    test(
      'corrupt lastCheckedAt string returns null without crashing',
      () async {
        // 直接寫入髒資料模擬過去版本寫的格式變動
        await db.setSetting('calibration.last_checked_at', 'not-a-date');

        final cached = await db.getCachedCalibration();

        expect(cached.lastCheckedAt, isNull);
      },
    );
  });
}
