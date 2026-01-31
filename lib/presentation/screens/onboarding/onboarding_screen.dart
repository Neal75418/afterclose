import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/app/router.dart' show completeOnboarding;

/// 首次使用引導頁面
///
/// 3 步驟介紹 AfterClose 核心功能，完成後標記已完成並導向主頁面。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// SharedPreferences key for tracking onboarding completion
  static const String completedKey = 'onboarding_complete';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text('onboarding.skip'.tr()),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _OnboardingPage(
                    icon: Icons.auto_awesome,
                    iconColor: theme.colorScheme.primary,
                    title: 'onboarding.step1Title'.tr(),
                    description: 'onboarding.step1Desc'.tr(),
                  ),
                  _OnboardingPage(
                    icon: Icons.analytics_outlined,
                    iconColor: Colors.orange,
                    title: 'onboarding.step2Title'.tr(),
                    description: 'onboarding.step2Desc'.tr(),
                  ),
                  _OnboardingPage(
                    icon: Icons.notifications_active_outlined,
                    iconColor: Colors.green,
                    title: 'onboarding.step3Title'.tr(),
                    description: 'onboarding.step3Desc'.tr(),
                  ),
                ],
              ),
            ),

            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: _currentPage == _totalPages - 1
                    ? FilledButton(
                        onPressed: _completeOnboarding,
                        child: Text('onboarding.getStarted'.tr()),
                      )
                    : FilledButton.tonal(
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text('onboarding.next'.tr()),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
