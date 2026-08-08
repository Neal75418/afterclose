import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:daredevil/core/services/notification_service.dart';
import 'package:daredevil/core/theme/design_tokens.dart';
import 'package:daredevil/presentation/providers/notification_provider.dart';

/// 通知診斷(2026-08-08)。
///
/// 為什麼需要這個:2026-08-08 實機發現點快捷鈕不會跳出授權對話框,而
/// 排查時只能靠猜——版本、簽章、初始化、entitlement 都排除了,仍不知道
/// 請求到底有沒有發出去。**沒有可觀察的狀態就沒有可驗證的修復**,所以
/// 把三個關鍵事實(已初始化/系統權限/請求結果)攤在畫面上,並提供一顆
/// 直接送測試通知的按鈕——收不收得到,一按便知。
class NotificationDiagnosticsTile extends ConsumerStatefulWidget {
  const NotificationDiagnosticsTile({super.key});

  @override
  ConsumerState<NotificationDiagnosticsTile> createState() =>
      _NotificationDiagnosticsTileState();
}

class _NotificationDiagnosticsTileState
    extends ConsumerState<NotificationDiagnosticsTile> {
  String? _lastAction;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 開啟面板就解析路徑並寫一行——這樣「路徑對不對」與「檔案寫不寫得
    // 進去」在使用者按任何按鈕**之前**就有答案。先前路徑只在按下按鈕後
    // 才解析,導致「還沒按」與「按了沒作用」在畫面上長得一樣,排查
    // 卡了好幾輪(2026-08-08)。
    Future.microtask(() async {
      await _ensureLogPath();
      _append('◆ 診斷面板開啟(此行由 initState 寫入,與按鈕無關)');
      if (mounted) setState(() {});
    });
  }

  /// 診斷紀錄檔——與 DB 同目錄,外部可直接讀。
  ///
  /// 為什麼要落檔(2026-08-08):排查通知問題時我一直卡在「使用者看到
  /// 什麼、再轉述給我」的迴圈,而畫面上的結果行有時根本沒出現,連
  /// 「按鈕有沒有真的觸發」都無法確定。
  ///
  /// ⚠️ 路徑**不可**用 `Platform.environment['HOME']` 組:macOS 沙盒
  /// 會把 HOME 重導到容器內,自組路徑會變成不存在的巢狀目錄、寫檔靜默
  /// 失敗(2026-08-08 實機:第一版就是這樣,診斷檔從未產生)。一律用
  /// path_provider——那也是 DB 自己在用的機制。
  String? _logPath;
  String? _logPathError;

  Future<void> _ensureLogPath() async {
    if (_logPath != null || _logPathError != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logPath = '${dir.path}/notification_diag.log';
    } catch (e) {
      _logPathError = '$e';
    }
  }

  void _append(String line) {
    final path = _logPath;
    if (path == null) return;
    try {
      File(path).writeAsStringSync(
        '${DateTime.now().toIso8601String()}  $line\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // 失敗要在畫面上看得見,不可再靜默吞掉
      _logPathError = '寫檔失敗:$e';
    }
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    await _ensureLogPath();
    _append('▶ 按下「$label」');
    setState(() => _busy = true);
    String result;
    try {
      result = await action();
    } catch (e, st) {
      // 例外本身就是最有價值的診斷,不可吞
      result = '例外:$e';
      _append('   stack: $st');
    }
    _append('◀ $label → $result');
    if (!mounted) {
      _append('   ⚠ widget 已卸載,畫面不會更新(但動作已完成)');
      return;
    }
    setState(() {
      _busy = false;
      _lastAction = '$label → $result';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final theme = Theme.of(context);

    String platform() {
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isAndroid) return 'Android';
      return Platform.operatingSystem;
    }

    Widget row(String label, String value, {bool bad = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: bad ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacing16,
        DesignTokens.spacing8,
        DesignTokens.spacing16,
        DesignTokens.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.notificationDiagnostics'.tr(),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: DesignTokens.spacing8),
          row('平台', platform()),
          // 兩個不同的旗標:singleton 在 main() 就初始化,provider 狀態
          // 只有每日更新後才同步——分開顯示才看得出問題在哪一層
          row(
            '通知服務(啟動時)',
            NotificationService.instance.isInitialized ? '已就緒' : '未就緒',
            bad: !NotificationService.instance.isInitialized,
          ),
          row(
            'Provider 狀態',
            state.isInitialized ? '已同步' : '未同步(正常,按下方按鈕即同步)',
            bad: false,
          ),
          row(
            '系統通知權限',
            state.hasPermission ? '已授權' : '未授權',
            bad: !state.hasPermission,
          ),
          if (state.error != null) row('最後錯誤', state.error!, bad: true),
          if (_logPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '紀錄檔:$_logPath',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_logPathError != null) row('紀錄檔問題', _logPathError!, bad: true),
          if (_lastAction != null) ...[
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              _lastAction!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spacing8),
          Wrap(
            spacing: DesignTokens.spacing8,
            runSpacing: DesignTokens.spacing8,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('初始化', () async {
                        await ref
                            .read(notificationProvider.notifier)
                            .initialize();
                        final s = ref.read(notificationProvider);
                        return 'initialized=${s.isInitialized} '
                            'permission=${s.hasPermission}';
                      }),
                child: const Text('重新初始化'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('請求權限', () async {
                        final ok = await ref
                            .read(notificationProvider.notifier)
                            .requestPermissions();
                        return ok ? '已授權' : '未授權(對話框可能未出現)';
                      }),
                child: const Text('請求通知權限'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _run('測試通知', () async {
                        await NotificationService.instance.showPriceAlert(
                          id: 999999,
                          symbol: 'TEST',
                          title: 'Daredevil 測試通知',
                          body: '看到這則就代表通知管道可用',
                        );
                        return '已送出(未跳出=系統攔截或無權限)';
                      }),
                child: const Text('送測試通知'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
