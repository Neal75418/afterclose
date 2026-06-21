import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/add_transaction_sheet.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 持倉明細頁面
class PositionDetailScreen extends ConsumerWidget {
  const PositionDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final portfolioState = ref.watch(portfolioProvider);
    final transactionsAsync = ref.watch(positionTransactionsProvider(symbol));

    final position = portfolioState.positions.where((p) => p.symbol == symbol);
    final pos = position.isNotEmpty ? position.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pos != null ? '${pos.symbol} ${pos.stockName ?? ""}' : symbol,
        ),
      ),
      body: pos == null
          ? Center(child: Text('portfolio.noPositions'.tr()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 持倉資訊卡片
                _buildPositionSummary(theme, pos),
                const SizedBox(height: 24),

                // 交易紀錄標題
                Text(
                  'portfolio.transactionHistory'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // 交易紀錄列表
                transactionsAsync.when(
                  data: (txList) =>
                      _buildTransactionList(context, ref, theme, txList),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          ErrorDisplay.message(e),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(
                            positionTransactionsProvider(symbol),
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text('common.retry'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.sheetMaxWidth,
            ),
            builder: (context) => AddTransactionSheet(initialSymbol: symbol),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPositionSummary(ThemeData theme, PortfolioPositionData pos) {
    final isPositive = pos.unrealizedPnl >= 0;
    final pnlColor = pos.unrealizedPnl == 0
        ? theme.colorScheme.onSurface
        : (isPositive ? AppTheme.upColor : AppTheme.downColor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InfoTile(
                label: 'portfolio.quantity'.tr(),
                value: 'portfolio.sharesDisplay'.tr(
                  namedArgs: {'count': pos.quantity.toStringAsFixed(0)},
                ),
                theme: theme,
              ),
              _InfoTile(
                label: 'portfolio.avgCost'.tr(),
                value: AppNumberFormat.currency(pos.avgCost, decimals: 1),
                theme: theme,
              ),
              _InfoTile(
                label: 'portfolio.currentPrice'.tr(),
                value: AppNumberFormat.currency(
                  pos.currentPrice ?? 0,
                  decimals: 1,
                ),
                theme: theme,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _InfoTile(
                label: 'portfolio.marketValue'.tr(),
                value: AppNumberFormat.currency(pos.marketValue),
                theme: theme,
              ),
              _InfoTile(
                label: 'portfolio.unrealizedPnl'.tr(),
                value:
                    '${isPositive ? "+" : ""}${pos.unrealizedPnl.toStringAsFixed(0)}',
                theme: theme,
                valueColor: pnlColor,
              ),
              _InfoTile(
                label: '',
                value:
                    '(${isPositive ? "+" : ""}${pos.unrealizedPnlPct.toStringAsFixed(1)}%)',
                theme: theme,
                valueColor: pnlColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoTile(
                label: 'portfolio.realizedPnl'.tr(),
                value: pos.realizedPnl.toStringAsFixed(0),
                theme: theme,
                valueColor: pos.realizedPnl >= 0
                    ? AppTheme.upColor
                    : AppTheme.downColor,
              ),
              _InfoTile(
                label: 'portfolio.dividendIncome'.tr(),
                value: AppNumberFormat.signedCurrency(
                  pos.totalDividendReceived,
                ),
                theme: theme,
                valueColor: pos.totalDividendReceived > 0
                    ? AppTheme.upColor
                    : null,
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<PortfolioTransactionEntry> txList,
  ) {
    if (txList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'portfolio.noTransactions'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    // 倒序顯示（最新的在上面）
    final reversed = txList.reversed.toList();

    return Column(
      children: [
        for (final tx in reversed) ...[
          _TransactionRow(
            tx: tx,
            theme: theme,
            onEdit: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.sheetMaxWidth,
                ),
                builder: (_) =>
                    AddTransactionSheet(initialSymbol: symbol, existingTx: tx),
              );
              // 編輯完成後刷新交易紀錄
              ref.invalidate(positionTransactionsProvider(symbol));
            },
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('portfolio.deleteTransaction'.tr()),
                  content: Text('portfolio.deleteConfirm'.tr()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        MaterialLocalizations.of(ctx).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                // 保留交易資料以供 undo
                final deletedTx = tx;
                try {
                  await ref
                      .read(portfolioProvider.notifier)
                      .deleteTransaction(tx.id, symbol);
                  // 刷新交易紀錄
                  ref.invalidate(positionTransactionsProvider(symbol));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('portfolio.transactionDeleted'.tr()),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(
                          seconds: ApiConfig.longMessageDurationSec,
                        ),
                        showCloseIcon: true,
                        dismissDirection: DismissDirection.horizontal,
                        action: SnackBarAction(
                          label: 'watchlist.undo'.tr(),
                          onPressed: () async {
                            try {
                              final notifier = ref.read(
                                portfolioProvider.notifier,
                              );
                              final txType = TransactionType.fromValue(
                                deletedTx.txType,
                              );
                              switch (txType) {
                                case TransactionType.buy:
                                  await notifier.addBuy(
                                    symbol: deletedTx.symbol,
                                    date: deletedTx.date,
                                    quantity: deletedTx.quantity,
                                    price: deletedTx.price,
                                    fee: deletedTx.fee > 0
                                        ? deletedTx.fee
                                        : null,
                                    note: deletedTx.note,
                                  );
                                case TransactionType.sell:
                                  await notifier.addSell(
                                    symbol: deletedTx.symbol,
                                    date: deletedTx.date,
                                    quantity: deletedTx.quantity,
                                    price: deletedTx.price,
                                    fee: deletedTx.fee > 0
                                        ? deletedTx.fee
                                        : null,
                                    tax: deletedTx.tax > 0
                                        ? deletedTx.tax
                                        : null,
                                    note: deletedTx.note,
                                  );
                                case TransactionType.dividendCash:
                                  await notifier.addDividend(
                                    symbol: deletedTx.symbol,
                                    date: deletedTx.date,
                                    amount: deletedTx.quantity,
                                    isCash: true,
                                    note: deletedTx.note,
                                  );
                                case TransactionType.dividendStock:
                                  await notifier.addDividend(
                                    symbol: deletedTx.symbol,
                                    date: deletedTx.date,
                                    amount: deletedTx.quantity,
                                    isCash: false,
                                    note: deletedTx.note,
                                  );
                              }
                              ref.invalidate(
                                positionTransactionsProvider(symbol),
                              );
                            } catch (e) {
                              AppLogger.warning(
                                'PositionDetailScreen',
                                '復原交易失敗',
                                e,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ErrorDisplay.message(e)),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  AppLogger.warning('PositionDetailScreen', '刪除交易失敗', e);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ErrorDisplay.message(e)),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (label.isNotEmpty) const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.tx,
    required this.theme,
    required this.onDelete,
    this.onEdit,
  });

  final PortfolioTransactionEntry tx;
  final ThemeData theme;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final txType = TransactionType.fromValue(tx.txType);
    final isBuy = txType == TransactionType.buy;
    final isSell = txType == TransactionType.sell;
    final isDividend =
        txType == TransactionType.dividendCash ||
        txType == TransactionType.dividendStock;

    final color = isBuy
        ? AppTheme.upColor
        : (isSell ? AppTheme.downColor : AppTheme.primaryColor);

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              // 日期
              SizedBox(
                width: 80,
                child: Text(
                  DateFormat('yyyy-MM-dd').format(tx.date),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              // 類型
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                ),
                child: Text(
                  txType.i18nKey.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // 金額
              if (isDividend)
                Text(
                  AppNumberFormat.signedCurrency(tx.quantity),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '${tx.quantity.toStringAsFixed(0)} @ ${AppNumberFormat.currency(tx.price, decimals: 1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
