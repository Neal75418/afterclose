import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// API Token configuration tile
class ApiTokenTile extends ConsumerStatefulWidget {
  const ApiTokenTile({super.key});

  @override
  ConsumerState<ApiTokenTile> createState() => _ApiTokenTileState();
}

class _ApiTokenTileState extends ConsumerState<ApiTokenTile> {
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
      controller.dispose();
    });
  }

  Future<void> _saveToken(String token) async {
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
