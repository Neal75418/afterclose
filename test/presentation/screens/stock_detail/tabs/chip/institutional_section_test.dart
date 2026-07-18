import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/color_contrast.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/institutional_section.dart';

import '../../../../../helpers/widget_test_helpers.dart';

/// 紅區：hue >= 345 或 <= 15。綠區：88 <= hue <= 175。
///
/// 與 `test/core/theme/semantic_colors_test.dart` 的同名 helper 邏輯一致
/// ——Dart 的 `_` 前綴僅限同檔案私有、無法跨檔案 import，故比照複製而非
/// 共用一份，但判準必須維持一致，不得各寫一套。
bool _inPriceHueZone(Color c) {
  final h = ColorContrast.hue(c);
  if (h < 0) return false; // 灰階不佔用色相，顯然安全，不落在任何禁區
  return h >= 345 || h <= 15 || (h >= 88 && h <= 175);
}

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  DailyInstitutionalEntry createEntry({
    String symbol = '2330',
    DateTime? date,
    double? foreignNet = 500,
    double? investmentTrustNet = 200,
    double? dealerNet = -100,
  }) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: date ?? DateTime(2026, 2, 14),
      foreignNet: foreignNet,
      investmentTrustNet: investmentTrustNet,
      dealerNet: dealerNet,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpSection(
    WidgetTester tester,
    Widget widget, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(buildTestApp(widget, brightness: brightness));
    await tester.pump(const Duration(seconds: 1));
  }

  group('InstitutionalSection', () {
    testWidgets('displays business icon', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, InstitutionalSection(history: [createEntry()]));

      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (tester) async {
      widenViewport(tester);
      await pumpSection(tester, const InstitutionalSection(history: []));

      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('displays summary cards with data', (tester) async {
      widenViewport(tester);
      await pumpSection(
        tester,
        InstitutionalSection(
          history: [
            createEntry(
              foreignNet: 1000,
              investmentTrustNet: 500,
              dealerNet: -200,
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.store), findsOneWidget);
    });
  });

  group('法人分類色移除 —— CategoryColors.neutral 色彩語意守門', () {
    test('法人分類標記不佔用股價語意色相', () {
      // 注意：`#A1A1AA`（Zinc 400）R=161 G=161 B=170，B 分量不同，
      // 並非純灰階 —— 其色相為 240°。此處要求的是「不落在紅綠禁區」，
      // 不是「必須為純灰階」。與 PriceColors.flat 不同：後者的設計意圖
      // 明確要求純灰階（刻意不佔用任何色相），故其值為 #A1A1A1。
      //
      // 用 _inPriceHueZone 而非直接比較 hue 邊界：ColorContrast.hue() 對
      // 純灰階回傳哨兵值 -1，若未套用「h < 0 視為安全」guard，未來若
      // CategoryColors.neutral 改為純灰階（例如比照 PriceColors.flat 的
      // #A1A1A1）會被「-1 <= 15」誤判為落入紅區，造成假性失敗。
      expect(_inPriceHueZone(CategoryColors.neutral), isFalse);
    });

    test('法人分類標記對卡片底達 AA 4.5:1', () {
      expect(
        ColorContrast.ratio(CategoryColors.neutral, SemanticColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
