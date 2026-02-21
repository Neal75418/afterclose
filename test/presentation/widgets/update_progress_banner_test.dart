import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/widgets/update_progress_banner.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('UpdateProgressBanner', () {
    // The banner uses flutter_animate shimmer with repeat() for in-progress
    // states (0 < progress < 1), creating timers that outlive the test.
    // Use progress=1.0 (completed) to avoid the shimmer repeating timer,
    // or clean up by replacing the widget tree before test ends.

    testWidgets('displays message text', (tester) async {
      // Use 100% progress to avoid shimmer repeat timer
      const progress = UpdateProgress(
        currentStep: 10,
        totalSteps: 10,
        message: '更新股價資料...',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressBanner(progress: progress)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('更新股價資料...'), findsOneWidget);
    });

    testWidgets('displays step indicator', (tester) async {
      const progress = UpdateProgress(
        currentStep: 5,
        totalSteps: 5,
        message: '載入中',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressBanner(progress: progress)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('displays sync icon', (tester) async {
      const progress = UpdateProgress(
        currentStep: 5,
        totalSteps: 5,
        message: '同步中',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressBanner(progress: progress)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('shows percentage text at completion', (tester) async {
      const progress = UpdateProgress(
        currentStep: 10,
        totalSteps: 10,
        message: '完成',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressBanner(progress: progress)),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      const progress = UpdateProgress(
        currentStep: 3,
        totalSteps: 3,
        message: '暗色模式',
      );
      await tester.pumpWidget(
        buildTestApp(
          const UpdateProgressBanner(progress: progress),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(UpdateProgressBanner), findsOneWidget);
    });
  });

  group('UpdateProgressCompact', () {
    testWidgets('displays step count', (tester) async {
      const progress = UpdateProgress(
        currentStep: 3,
        totalSteps: 7,
        message: '載入中',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressCompact(progress: progress)),
      );

      expect(find.text('3/7'), findsOneWidget);
    });

    testWidgets('contains CircularProgressIndicator', (tester) async {
      const progress = UpdateProgress(
        currentStep: 5,
        totalSteps: 10,
        message: '載入中',
      );
      await tester.pumpWidget(
        buildTestApp(const UpdateProgressCompact(progress: progress)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      const progress = UpdateProgress(
        currentStep: 1,
        totalSteps: 3,
        message: '暗色',
      );
      await tester.pumpWidget(
        buildTestApp(
          const UpdateProgressCompact(progress: progress),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(UpdateProgressCompact), findsOneWidget);
    });
  });
}
