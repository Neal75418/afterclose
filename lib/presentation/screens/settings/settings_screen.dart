import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/services/background_update_service.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/screens/settings/widgets/api_token_tile.dart';
import 'package:afterclose/presentation/screens/settings/widgets/data_management_tile.dart';
import 'package:afterclose/presentation/widgets/common/radio_selection_dialog.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Supported locales with display names
const _supportedLocales = [
  (locale: Locale('zh', 'TW'), name: '繁體中文'),
  (locale: Locale('en'), name: 'English'),
];

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      body: ListView(
        children: [
          // API Section
          _buildSettingsSection(context, 'settings.api'.tr(), [
            const ApiTokenTile(),
          ]),

          // Theme Section
          _buildSettingsSection(context, 'settings.appearance'.tr(), [
            _buildThemeTile(context, ref, theme, settings),
          ]),

          // Language Section
          _buildSettingsSection(context, 'settings.language'.tr(), [
            _buildLanguageTile(context, theme, currentLocale),
          ]),

          // Advanced Features Section
          _buildSettingsSection(context, 'settings.advancedFeatures'.tr(), [
            _buildFeatureTile(
              context,
              settings.showWarningBadges,
              Icons.warning_amber_rounded,
              Colors.orange,
              'settings.showWarningBadges'.tr(),
              (v) =>
                  ref.read(settingsProvider.notifier).setShowWarningBadges(v),
            ),
            _buildFeatureTile(
              context,
              settings.insiderNotifications,
              Icons.people_alt_rounded,
              Colors.blue,
              'settings.insiderNotifications'.tr(),
              (v) => ref
                  .read(settingsProvider.notifier)
                  .setInsiderNotifications(v),
            ),
            _buildFeatureTile(
              context,
              settings.disposalUrgentAlerts,
              Icons.dangerous_rounded,
              Colors.red,
              'settings.disposalUrgentAlerts'.tr(),
              (v) => ref
                  .read(settingsProvider.notifier)
                  .setDisposalUrgentAlerts(v),
            ),
            _buildFeatureTile(
              context,
              settings.limitAlerts,
              Icons.vertical_align_center_rounded,
              Colors.deepOrange,
              'settings.limitAlerts'.tr(),
              (v) => ref.read(settingsProvider.notifier).setLimitAlerts(v),
            ),
            _buildFeatureTile(
              context,
              settings.showROCYear,
              Icons.calendar_month_rounded,
              Colors.purple,
              'settings.showROCYear'.tr(),
              (v) => ref.read(settingsProvider.notifier).setShowROCYear(v),
            ),
            _buildCacheDurationTile(context, ref, theme, settings),
          ]),

          // Background Update Section (only on supported platforms)
          if (BackgroundUpdateService.isSupported)
            _buildSettingsSection(context, 'settings.backgroundUpdate'.tr(), [
              _buildAutoUpdateTile(context, ref, theme, settings),
            ]),

          // Data Management Section
          _buildSettingsSection(context, 'settings.dataManagement'.tr(), [
            const DataManagementTile(),
          ]),

          // About Section
          _buildSettingsSection(context, 'settings.about'.tr(), [
            _buildAboutTile(context, theme),
            _buildVersionTile(theme),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconContainer(Color color, IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SettingsState settings,
  ) {
    return ListTile(
      leading: _buildIconContainer(
        Colors.indigo,
        _getThemeIcon(settings.themeMode),
      ),
      title: Text('settings.themeMode'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getThemeModeLabel(settings.themeMode),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => RadioSelectionDialog.show<ThemeMode>(
        context: context,
        title: 'settings.selectTheme'.tr(),
        options: ThemeMode.values,
        currentValue: settings.themeMode,
        labelBuilder: _getThemeModeLabel,
        trailingBuilder: (mode) => Icon(_getThemeIcon(mode)),
        onSelected: (mode) =>
            ref.read(settingsProvider.notifier).setThemeMode(mode),
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    ThemeData theme,
    Locale currentLocale,
  ) {
    final currentName = _supportedLocales
        .firstWhere(
          (l) => l.locale.languageCode == currentLocale.languageCode,
          orElse: () => _supportedLocales.first,
        )
        .name;

    return ListTile(
      leading: _buildIconContainer(Colors.teal, Icons.language_rounded),
      title: Text('settings.language'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => RadioSelectionDialog.show(
        context: context,
        title: 'settings.selectLanguage'.tr(),
        options: _supportedLocales.map((l) => l.locale).toList(),
        currentValue: _supportedLocales
            .firstWhere(
              (l) => l.locale.languageCode == currentLocale.languageCode,
              orElse: () => _supportedLocales.first,
            )
            .locale,
        labelBuilder: (locale) =>
            _supportedLocales.firstWhere((l) => l.locale == locale).name,
        onSelected: (locale) => context.setLocale(locale),
      ),
    );
  }

  Widget _buildAboutTile(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: _buildIconContainer(
        Colors.grey[700]!,
        Icons.info_outline_rounded,
      ),
      title: Text('settings.aboutApp'.tr()),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => _showAboutDialog(context),
    );
  }

  Widget _buildVersionTile(ThemeData theme) {
    return ListTile(
      leading: _buildIconContainer(Colors.blueGrey, Icons.verified_rounded),
      title: Text('settings.version'.tr()),
      trailing: Text(
        '1.0.0',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context,
    bool value,
    IconData icon,
    Color color,
    String title,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      secondary: _buildIconContainer(color, icon),
      title: Text(title),
      value: value,
      onChanged: (newValue) {
        HapticFeedback.selectionClick();
        onChanged(newValue);
      },
    );
  }

  Widget _buildCacheDurationTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SettingsState settings,
  ) {
    final label = switch (settings.cacheDurationMinutes) {
      15 => 'settings.cache15min'.tr(),
      30 => 'settings.cache30min'.tr(),
      60 => 'settings.cache60min'.tr(),
      _ => '${settings.cacheDurationMinutes} min',
    };

    return ListTile(
      leading: _buildIconContainer(Colors.cyan, Icons.cached_rounded),
      title: Text('settings.cacheDuration'.tr()),
      subtitle: Text(
        'settings.cacheDurationDesc'.tr(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => RadioSelectionDialog.show<int>(
        context: context,
        title: 'settings.selectCacheDuration'.tr(),
        options: const [15, 30, 60],
        currentValue: settings.cacheDurationMinutes,
        labelBuilder: (minutes) => switch (minutes) {
          15 => 'settings.cache15min'.tr(),
          30 => 'settings.cache30min'.tr(),
          60 => 'settings.cache60min'.tr(),
          _ => '$minutes min',
        },
        onSelected: (minutes) {
          ref.read(settingsProvider.notifier).setCacheDurationMinutes(minutes);
          ref.invalidate(finMindClientProvider);
        },
      ),
    );
  }

  Widget _buildAutoUpdateTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SettingsState settings,
  ) {
    return SwitchListTile(
      secondary: _buildIconContainer(Colors.green, Icons.sync_rounded),
      title: Text('settings.autoUpdate'.tr()),
      subtitle: Text(
        'settings.autoUpdateDesc'.tr(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      value: settings.autoUpdateEnabled,
      onChanged: (newValue) async {
        HapticFeedback.selectionClick();
        ref.read(settingsProvider.notifier).setAutoUpdateEnabled(newValue);

        // 啟用或停用背景更新服務
        if (newValue) {
          await BackgroundUpdateService.instance.enableAutoUpdate();
        } else {
          await BackgroundUpdateService.instance.disableAutoUpdate();
        }
      },
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
  }

  String _getThemeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'settings.themeLight'.tr(),
      ThemeMode.dark => 'settings.themeDark'.tr(),
      ThemeMode.system => 'settings.themeSystem'.tr(),
    };
  }

  void _showAboutDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showAboutDialog(
      context: context,
      applicationName: 'app.name'.tr(),
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Icon(
          Icons.show_chart_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text('settings.aboutDescription'.tr()),
        const SizedBox(height: 16),
        Text(
          '© ${DateTime.now().year} AfterClose',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
