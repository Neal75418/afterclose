import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/connectivity_provider.dart';

/// 帶有響應式導覽的外殼 Widget
///
/// - 手機：底部導覽列（NavigationBar）
/// - 平板/桌面：側邊導覽欄（NavigationRail）
/// - 離線時顯示提示橫幅
///
/// 使用 GlobalKey 包住 [StatefulNavigationShell]，確保在底部導覽列
/// 與側邊導覽欄之間切換時 Element tree 被保留而非 unmount/remount，
/// 避免第一次點擊不響應的問題。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// 確保 navigationShell 在佈局切換時被 reparent 而非重建
  final _shellKey = GlobalKey();

  void _onDestinationSelected(int index) {
    if (index != widget.navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowRail = context.shouldShowNavigationRail;
    final isOnline = ref.watch(connectivityProvider).value ?? true;

    final shell = KeyedSubtree(key: _shellKey, child: widget.navigationShell);

    final body = shouldShowRail
        ? _buildRailLayout(context, shell)
        : _buildBottomNavLayout(shell);

    if (isOnline) return body;

    return Column(
      children: [
        _OfflineBanner(),
        Expanded(child: body),
      ],
    );
  }

  /// 手機佈局：底部導覽列
  Widget _buildBottomNavLayout(Widget shell) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _buildNavigationDestinations(),
      ),
    );
  }

  /// 平板/桌面佈局：側邊導覽欄
  Widget _buildRailLayout(BuildContext context, Widget shell) {
    final theme = Theme.of(context);
    final isExtended = context.isDesktop;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            extended: isExtended,
            minWidth: 72,
            minExtendedWidth: 200,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primaryContainer,
            labelType: isExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            leading: isExtended
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'AfterClose',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : const SizedBox(height: 16),
            destinations: _buildRailDestinations(),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }

  /// 建立底部導覽目的地
  List<NavigationDestination> _buildNavigationDestinations() {
    return [
      NavigationDestination(
        icon: const Icon(Icons.today_outlined),
        selectedIcon: const Icon(Icons.today),
        label: 'nav.today'.tr(),
      ),
      NavigationDestination(
        icon: const Icon(Icons.search_outlined),
        selectedIcon: const Icon(Icons.search),
        label: 'nav.scan'.tr(),
      ),
      NavigationDestination(
        icon: const Icon(Icons.star_outline),
        selectedIcon: const Icon(Icons.star),
        label: 'nav.watchlist'.tr(),
      ),
      NavigationDestination(
        icon: const Icon(Icons.newspaper_outlined),
        selectedIcon: const Icon(Icons.newspaper),
        label: 'nav.news'.tr(),
      ),
    ];
  }

  /// 建立側邊導覽目的地
  List<NavigationRailDestination> _buildRailDestinations() {
    return [
      NavigationRailDestination(
        icon: const Icon(Icons.today_outlined),
        selectedIcon: const Icon(Icons.today),
        label: Text('nav.today'.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.search_outlined),
        selectedIcon: const Icon(Icons.search),
        label: Text('nav.scan'.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.star_outline),
        selectedIcon: const Icon(Icons.star),
        label: Text('nav.watchlist'.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.newspaper_outlined),
        selectedIcon: const Icon(Icons.newspaper),
        label: Text('nav.news'.tr()),
      ),
    ];
  }
}

/// 離線提示橫幅
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 16,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'common.offline'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
