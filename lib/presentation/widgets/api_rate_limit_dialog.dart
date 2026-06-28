import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 資料源流量限制的共用判斷與對話框。
///
/// 同步會打多個資料源（FinMind / TWSE / TPEx）。FinMind 是每小時 600 次硬上限；
/// TWSE/TPEx 是密集請求觸發的瞬時反爬限流（redirect loop），稍候即恢復。兩者
/// 指引不同，故對話框依 vendor 顯示對應訊息，避免把 TWSE 限流誤報成 FinMind。

/// 是否為流量限制類錯誤（任一資料源）。
bool isRateLimitError(String e) =>
    e.contains('流量') ||
    e.contains('限流') ||
    e.contains('限制') ||
    e.contains('limit') ||
    e.contains('quota') ||
    e.contains('429');

/// 限流是否來自 FinMind（每小時上限）；否則視為 TWSE/TPEx 瞬時反爬限流。
bool isFinMindRateLimit(String e) => e.toLowerCase().contains('finmind');

/// 顯示流量限制對話框，依 [finMind] 給對應訊息與指引。
void showApiRateLimitDialog(BuildContext context, {required bool finMind}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 48,
      ),
      title: Text('settings.rateLimitTitle'.tr()),
      content: Text(
        (finMind
                ? 'settings.rateLimitMessageFinMind'
                : 'settings.rateLimitMessageTransient')
            .tr(),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('settings.rateLimitOk'.tr()),
        ),
      ],
    ),
  );
}
