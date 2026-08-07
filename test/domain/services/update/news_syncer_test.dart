import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/data/repositories/news_repository.dart';
import 'package:daredevil/domain/repositories/news_repository.dart' as repo_if;
import 'package:daredevil/domain/services/update/news_syncer.dart';

class MockNewsRepository extends Mock implements NewsRepository {}

/// NewsSyncer 錯誤處理慣例(2026-08-01 全專案 smell 掃描 Tier 1)。
///
/// 修前它是十個 syncer 中唯一裸 catch 的:RateLimitException 被降級成
/// errors 字串,而 UpdateService._syncNews 又恰是唯一沒有
/// rateLimitedAbort guard 的步驟——TWSE 重大訊息端點被限流時,整個
/// 「防止下游繼續打被限流 API」的熔斷對這條路徑失效。
void main() {
  late MockNewsRepository mockRepo;
  late NewsSyncer syncer;

  setUp(() {
    mockRepo = MockNewsRepository();
    syncer = NewsSyncer(newsRepository: mockRepo);
  });

  test('🚨 重大訊息限流必須 rethrow(熔斷洞:RSS 成功後材料訊息 429)', () async {
    when(() => mockRepo.syncNews()).thenAnswer(
      (_) async => const repo_if.NewsSyncResult(itemsAdded: 5, errors: []),
    );
    when(
      () => mockRepo.syncMaterialInfo(),
    ).thenThrow(const RateLimitException('429'));

    await expectLater(syncer.syncNews(), throwsA(isA<RateLimitException>()));
  });

  test('RSS 限流必須 rethrow', () async {
    when(() => mockRepo.syncNews()).thenThrow(const RateLimitException('429'));

    await expectLater(syncer.syncNews(), throwsA(isA<RateLimitException>()));
  });

  test('NetworkException 必須 rethrow', () async {
    when(() => mockRepo.syncNews()).thenAnswer(
      (_) async => const repo_if.NewsSyncResult(itemsAdded: 0, errors: []),
    );
    when(
      () => mockRepo.syncMaterialInfo(),
    ).thenThrow(const NetworkException('offline'));

    await expectLater(syncer.syncNews(), throwsA(isA<NetworkException>()));
  });

  test('一般錯誤維持 fail-soft:記 errors、RSS 結果不被吞', () async {
    when(() => mockRepo.syncNews()).thenAnswer(
      (_) async => const repo_if.NewsSyncResult(itemsAdded: 7, errors: []),
    );
    when(() => mockRepo.syncMaterialInfo()).thenThrow(StateError('parse boom'));

    final result = await syncer.syncNews();

    expect(result.itemsAdded, 7);
    expect(result.errors, hasLength(1));
    expect(result.errors.single, contains('重大訊息'));
  });
}
