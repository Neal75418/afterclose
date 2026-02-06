import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/event_calendar_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 新增事件 BottomSheet
class AddEventSheet extends ConsumerStatefulWidget {
  const AddEventSheet({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _symbolController = TextEditingController();

  late DateTime _date;
  String? _selectedSymbol;

  // 搜尋結果
  List<StockMasterEntry> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題列
            Row(
              children: [
                Text(
                  'calendar.addEvent'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 事件標題
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'calendar.eventTitle'.tr(),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              maxLength: 100,
            ),
            const SizedBox(height: 12),

            // 事件日期
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'calendar.eventDate'.tr(),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(_date)),
              ),
            ),
            const SizedBox(height: 12),

            // 關聯股票（選填）
            TextField(
              controller: _symbolController,
              decoration: InputDecoration(
                labelText: 'calendar.eventStock'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: _selectedSymbol != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedSymbol = null;
                            _symbolController.clear();
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _onSymbolSearch,
            ),

            // 搜尋結果
            if (_searchResults.isNotEmpty && _selectedSymbol == null)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final stock = _searchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text('${stock.symbol} ${stock.name}'),
                      onTap: () {
                        setState(() {
                          _selectedSymbol = stock.symbol;
                          _symbolController.text =
                              '${stock.symbol} ${stock.name}';
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // 描述
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'calendar.eventDescription'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // 按鈕
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      MaterialLocalizations.of(context).okButtonLabel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _onSymbolSearch(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    if (_isSearching) return;
    _isSearching = true;

    try {
      final db = ref.read(databaseProvider);
      final results = await db.searchStocks(query);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } finally {
      _isSearching = false;
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('calendar.titleRequired'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ref
          .read(eventCalendarProvider.notifier)
          .addEvent(
            symbol: _selectedSymbol,
            eventDate: _date,
            title: title,
            description: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar.eventAdded'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
