import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/error_display.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('ErrorDisplay.message', () {
    test('ValidationException returns translated messageKey (not unknown)', () {
      const error = ValidationException('portfolio.sellExceedsHolding');
      final msg = ErrorDisplay.message(error);
      // 翻譯檔 fallback 為 zh-TW；若 init 未載入翻譯，至少不該回 'error.unknown'。
      expect(msg, isNot('error.unknown'));
      expect(msg, isNot('未知錯誤'));
    });

    test(
      'ValidationException with unknown key returns key (not unknown fallback)',
      () {
        const error = ValidationException('nonexistent.key.foo');
        final msg = ErrorDisplay.message(error);
        // easy_localization 對無對應翻譯回 key 本身；保證沒退到 unknown。
        expect(msg, equals('nonexistent.key.foo'));
      },
    );

    test('Other AppException still returns its message verbatim', () {
      const error = DatabaseException('db fubar');
      expect(ErrorDisplay.message(error), 'db fubar');
    });

    test('SocketException returns network i18n key', () {
      final error = const SocketException('boom');
      // 翻譯檔已有 error.network；只要不是 unknown 即可。
      expect(ErrorDisplay.message(error), isNot('error.unknown'));
    });

    test('Unknown stdlib type falls back to error.unknown key', () {
      // StateError / ArgumentError 不再用於使用者輸入驗證（H4 修正）；
      // 若還有其他 stdlib type 漏網，會走 unknown。
      final error = ArgumentError('legacy path');
      // setupTestLocalization 沒載完整 translation map，
      // .tr() 對未知 key 回傳 key 本身。
      expect(ErrorDisplay.message(error), 'error.unknown');
    });

    test('TimeoutException returns timeout i18n key', () {
      final error = TimeoutException('slow');
      expect(ErrorDisplay.message(error), isNot('error.unknown'));
    });
  });
}
