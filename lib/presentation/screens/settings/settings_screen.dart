import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';

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
        ),
      ),
      body: ListView(
        children: [
          // API Section
          _buildSectionHeader(theme, 'settings.api'.tr()),
          const _ApiTokenTile(),
          const Divider(height: 1),

          // Theme Section
          _buildSectionHeader(theme, 'settings.appearance'.tr()),
          _buildThemeTile(context, ref, theme, settings),
          const Divider(height: 1),

          // Language Section
          _buildSectionHeader(theme, 'settings.language'.tr()),
          _buildLanguageTile(context, theme, currentLocale),
          const Divider(height: 1),

          // About Section
          _buildSectionHeader(theme, 'settings.about'.tr()),
          _buildAboutTile(context, theme),
          _buildVersionTile(theme),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SettingsState settings,
  ) {
    return ListTile(
      leading: Icon(
        _getThemeIcon(settings.themeMode),
        color: theme.colorScheme.primary,
      ),
      title: Text('settings.themeMode'.tr()),
      subtitle: Text(_getThemeModeLabel(settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
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
      leading: Icon(
        Icons.language_rounded,
        color: theme.colorScheme.primary,
      ),
      title: Text('settings.language'.tr()),
      subtitle: Text(currentName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, currentLocale),
    );
  }

  Widget _buildAboutTile(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.info_outline_rounded,
        color: theme.colorScheme.primary,
      ),
      title: Text('settings.aboutApp'.tr()),
      subtitle: Text('settings.aboutDescription'.tr()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showAboutDialog(context),
    );
  }

  Widget _buildVersionTile(ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.verified_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('settings.version'.tr()),
      subtitle: const Text('1.0.0'),
      enabled: false,
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
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? Theme.of(dialogContext).colorScheme.primary : null,
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

  void _showLanguageDialog(
    BuildContext context,
    Locale currentLocale,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.selectLanguage'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _supportedLocales.map((item) {
            final isSelected = item.locale.languageCode == currentLocale.languageCode;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? Theme.of(dialogContext).colorScheme.primary : null,
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
            colors: [
              AppTheme.primaryColor,
              AppTheme.secondaryColor,
            ],
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

    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final token = await settingsRepo.getFinMindToken();

      final client = FinMindClient(token: token);
      final stocks = await client.getStockList();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResult = 'settings.apiTestSuccess'.tr(args: [stocks.length.toString()]);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = 'settings.apiTestFailed'.tr(args: [e.toString()]);
        });
      }
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

    // Update FinMindClient with new token
    ref.read(finMindClientProvider).token = token;

    if (mounted) {
      setState(() {
        _hasToken = true;
        _testResult = null;
        _testSuccess = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.apiTokenSaved'.tr())),
      );
    }
  }

  Future<void> _clearToken() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.clearFinMindToken();

    // Clear token from FinMindClient
    ref.read(finMindClientProvider).token = null;

    if (mounted) {
      setState(() {
        _hasToken = false;
        _testResult = null;
        _testSuccess = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.apiTokenCleared'.tr())),
      );
    }
  }

  Future<void> _openRegisterUrl() async {
    final url = Uri.parse('https://finmindtrade.com/');
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
            color: _hasToken ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text('settings.apiToken'.tr()),
          subtitle: Text(
            _hasToken ? 'settings.apiTokenSet'.tr() : 'settings.apiTokenNotSet'.tr(),
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
                    _isTesting ? 'settings.apiTesting'.tr() : 'settings.apiTestConnection'.tr(),
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
