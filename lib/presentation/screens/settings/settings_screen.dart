import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';

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
            const _ApiTokenTile(),
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

          // Data Management Section
          _buildSettingsSection(context, 'settings.dataManagement'.tr(), [
            _DataManagementTile(),
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
            borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(8),
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
      onTap: () => _showThemeDialog(context, ref, settings.themeMode),
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
      onTap: () => _showLanguageDialog(context, currentLocale),
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
      onTap: () =>
          _showCacheDurationDialog(context, ref, settings.cacheDurationMinutes),
    );
  }

  void _showCacheDurationDialog(
    BuildContext context,
    WidgetRef ref,
    int currentMinutes,
  ) {
    HapticFeedback.lightImpact();
    final options = [15, 30, 60];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.selectCacheDuration'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            final isSelected = minutes == currentMinutes;
            final label = switch (minutes) {
              15 => 'settings.cache15min'.tr(),
              30 => 'settings.cache30min'.tr(),
              60 => 'settings.cache60min'.tr(),
              _ => '$minutes min',
            };
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
              title: Text(label),
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(settingsProvider.notifier)
                    .setCacheDurationMinutes(minutes);
                // Invalidate FinMind client to pick up new TTL
                ref.invalidate(finMindClientProvider);
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
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

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.selectTheme'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
              title: Text(_getThemeModeLabel(mode)),
              trailing: Icon(_getThemeIcon(mode)),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).setThemeMode(mode);
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, Locale currentLocale) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.selectLanguage'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _supportedLocales.map((item) {
            final isSelected =
                item.locale.languageCode == currentLocale.languageCode;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
              title: Text(item.name),
              onTap: () {
                HapticFeedback.selectionClick();
                context.setLocale(item.locale);
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
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

/// API Token configuration tile
class _ApiTokenTile extends ConsumerStatefulWidget {
  const _ApiTokenTile();

  @override
  ConsumerState<_ApiTokenTile> createState() => _ApiTokenTileState();
}

class _ApiTokenTileState extends ConsumerState<_ApiTokenTile> {
  bool _hasToken = false;
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadTokenStatus();
  }

  Future<void> _loadTokenStatus() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final hasToken = await settingsRepo.hasFinMindToken();
    if (mounted) {
      setState(() {
        _hasToken = hasToken;
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    // 使用 ApiConnectionService 取代直接建立 FinMindClient
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final connectionService = ref.read(apiConnectionServiceProvider);
    final token = await settingsRepo.getFinMindToken();

    final result = await connectionService.testFinMindConnection(token);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = result.success;
        _testResult = result.success
            ? 'settings.apiTestSuccess'.tr(
                namedArgs: {'count': result.stockCount.toString()},
              )
            : 'settings.apiTestFailed'.tr(
                namedArgs: {'error': result.errorMessage ?? 'Unknown error'},
              );
      });
    }
  }

  void _showTokenDialog() {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.apiToken'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'settings.apiTokenHint'.tr(),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _openRegisterUrl(),
              child: Text(
                'settings.apiRegister'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_hasToken)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _clearToken();
              },
              child: Text(
                'common.delete'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isNotEmpty) {
                Navigator.pop(dialogContext);
                await _saveToken(token);
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    ).then((_) {
      // Dispose controller when dialog is closed to prevent memory leak
      controller.dispose();
    });
  }

  Future<void> _saveToken(String token) async {
    // Validate token format
    if (!FinMindClient.isValidTokenFormat(token)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.apiTokenInvalid'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setFinMindToken(token);

    // Invalidate finMindClientProvider 讓所有依賴它的 provider 重新獲取新 token
    // 這比直接設定 .token 屬性更安全，確保所有相關 provider 使用新配置
    ref.invalidate(finMindClientProvider);

    if (mounted) {
      setState(() {
        _hasToken = true;
        _testResult = null;
        _testSuccess = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('settings.apiTokenSaved'.tr())));
    }
  }

  Future<void> _clearToken() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.clearFinMindToken();

    // Invalidate finMindClientProvider 讓所有依賴它的 provider 重新獲取（無 token）
    // 這比直接設定 .token = null 更安全，確保所有相關 provider 使用新配置
    ref.invalidate(finMindClientProvider);

    if (mounted) {
      setState(() {
        _hasToken = false;
        _testResult = null;
        _testSuccess = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('settings.apiTokenCleared'.tr())));
    }
  }

  Future<void> _openRegisterUrl() async {
    final url = Uri.parse(ApiEndpoints.finmindWebsite);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading...'),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(
            _hasToken ? Icons.key_rounded : Icons.key_off_rounded,
            color: _hasToken
                ? Colors.green
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text('settings.apiToken'.tr()),
          subtitle: Text(
            _hasToken
                ? 'settings.apiTokenSet'.tr()
                : 'settings.apiTokenNotSet'.tr(),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showTokenDialog,
        ),
        // Test connection button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(
                    _isTesting
                        ? 'settings.apiTesting'.tr()
                        : 'settings.apiTestConnection'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Test result
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _testSuccess == true ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _testSuccess == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _testSuccess == true ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Data management tile for force sync and historical data progress
class _DataManagementTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DataManagementTile> createState() =>
      _DataManagementTileState();
}

class _DataManagementTileState extends ConsumerState<_DataManagementTile> {
  bool _isSyncing = false;
  String? _syncResult;
  bool? _syncSuccess;
  ({int completed, int total})? _historyProgress;

  @override
  void initState() {
    super.initState();
    _loadHistoryProgress();
  }

  Future<void> _loadHistoryProgress() async {
    final db = ref.read(databaseProvider);
    final progress = await db.getHistoricalDataProgress();
    if (mounted) {
      setState(() => _historyProgress = progress);
    }
  }

  Future<void> _forceSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.forceSyncTitle'.tr()),
        content: Text('settings.forceSyncConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('settings.forceSync'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
      _syncResult = null;
      _syncSuccess = null;
    });

    try {
      final result = await ref
          .read(todayProvider.notifier)
          .runUpdate(forceFetch: true);

      if (mounted) {
        // Check for rate limit errors
        final hasRateLimitError = result.errors.any(
          (e) =>
              e.contains('流量') ||
              e.contains('limit') ||
              e.contains('quota') ||
              e.contains('429'),
        );

        if (hasRateLimitError) {
          _showRateLimitDialog();
        }

        setState(() {
          _isSyncing = false;
          _syncSuccess = result.success;
          _syncResult = result.success
              ? 'settings.forceSyncSuccess'.tr(
                  namedArgs: {
                    'prices': result.pricesUpdated.toString(),
                    'analyzed': result.stocksAnalyzed.toString(),
                  },
                )
              : 'settings.forceSyncFailed'.tr(
                  namedArgs: {
                    'error': result.errors.isNotEmpty
                        ? result.errors.first
                        : 'Unknown error',
                  },
                );
        });
        // Refresh historical data progress
        _loadHistoryProgress();
      }
    } catch (e) {
      if (mounted) {
        // Check if exception is rate limit related
        final errorStr = e.toString();
        final isRateLimit =
            errorStr.contains('流量') ||
            errorStr.contains('limit') ||
            errorStr.contains('quota') ||
            errorStr.contains('429');

        if (isRateLimit) {
          _showRateLimitDialog();
        }

        setState(() {
          _isSyncing = false;
          _syncSuccess = false;
          _syncResult = 'settings.forceSyncFailed'.tr(
            namedArgs: {'error': errorStr},
          );
        });
      }
    }
  }

  void _showRateLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text('settings.rateLimitTitle'.tr()),
        content: Text('settings.rateLimitMessage'.tr()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.rateLimitOk'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
          title: Text('settings.forceSync'.tr()),
          subtitle: Text('settings.forceSyncDescription'.tr()),
          trailing: _isSyncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isSyncing ? null : _forceSync,
        ),
        // Sync result
        if (_syncResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _syncSuccess == true ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _syncSuccess == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _syncResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _syncSuccess == true ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Historical data progress
        if (_historyProgress != null) _buildHistoryProgress(theme),
      ],
    );
  }

  Widget _buildHistoryProgress(ThemeData theme) {
    final progress = _historyProgress!;
    final percent = progress.total > 0
        ? (progress.completed / progress.total * 100).round()
        : 0;
    final isComplete = percent >= 100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.history,
                size: 16,
                color: isComplete
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.historyProgress'.tr(
                    namedArgs: {
                      'completed': progress.completed.toString(),
                      'total': progress.total.toString(),
                      'percent': percent.toString(),
                    },
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.total > 0
                  ? progress.completed / progress.total
                  : 0,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
