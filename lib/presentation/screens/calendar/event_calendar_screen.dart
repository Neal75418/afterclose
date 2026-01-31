import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/event_calendar_provider.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/add_event_sheet.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/event_list_tile.dart';

/// 事件行事曆頁面
class EventCalendarScreen extends ConsumerStatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  ConsumerState<EventCalendarScreen> createState() =>
      _EventCalendarScreenState();
}

class _EventCalendarScreenState extends ConsumerState<EventCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();

    Future.microtask(() => ref.read(eventCalendarProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventCalendarProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('calendar.title'.tr()),
        actions: [
          // 篩選
          PopupMenuButton<CalendarFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'calendar.filter'.tr(),
            initialValue: state.filter,
            onSelected: (filter) {
              ref.read(eventCalendarProvider.notifier).setFilter(filter);
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: CalendarFilter.all,
                  child: _FilterMenuItem(
                    label: 'calendar.filterAll'.tr(),
                    isSelected: state.filter == CalendarFilter.all,
                  ),
                ),
                PopupMenuItem(
                  value: CalendarFilter.watchlistOnly,
                  child: _FilterMenuItem(
                    label: 'calendar.filterWatchlist'.tr(),
                    isSelected: state.filter == CalendarFilter.watchlistOnly,
                  ),
                ),
                PopupMenuItem(
                  value: CalendarFilter.portfolioOnly,
                  child: _FilterMenuItem(
                    label: 'calendar.filterPortfolio'.tr(),
                    isSelected: state.filter == CalendarFilter.portfolioOnly,
                  ),
                ),
              ];
            },
          ),
          // 同步除權息
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncDividendEvents,
            tooltip: 'calendar.syncDividendEvents'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 日曆
          TableCalendar<StockEventEntry>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: (day) {
              final dateKey = DateTime(day.year, day.month, day.day);
              return state.events[dateKey] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              ref.read(eventCalendarProvider.notifier).selectDate(selectedDay);
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              ref
                  .read(eventCalendarProvider.notifier)
                  .loadMonthEvents(DateTime(focusedDay.year, focusedDay.month));
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                return _buildEventMarkers(events);
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextFormatter: (date, locale) =>
                  DateFormat.yMMMM(locale).format(date),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: theme.colorScheme.onPrimary),
              outsideDaysVisible: false,
            ),
          ),

          const Divider(height: 1),

          // 選取日期的事件列表
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.selectedDayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'calendar.noEvents'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final event = state.selectedDayEvents[index];
                      return EventListTile(
                        event: event,
                        onDelete: () => _confirmDelete(event),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEvent(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventMarkers(List<StockEventEntry> events) {
    // 取不重複的事件類型，按 enum 順序排列（最多顯示 3 個 dot）
    final types =
        events.map((e) => EventType.fromValue(e.eventType)).toSet().toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final displayTypes = types.take(3).toList();

    return Positioned(
      bottom: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: displayTypes.map((type) {
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: eventTypeColor(type),
              shape: BoxShape.circle,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddEventSheet(initialDate: _selectedDay),
    );
  }

  Future<void> _confirmDelete(StockEventEntry event) async {
    if (event.isAutoGenerated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('calendar.deleteEvent'.tr()),
        content: Text('calendar.deleteConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(eventCalendarProvider.notifier).deleteEvent(event.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('calendar.eventDeleted'.tr())));
      }
    }
  }

  Future<void> _syncDividendEvents() async {
    final count = await ref
        .read(eventCalendarProvider.notifier)
        .syncDividendEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'calendar.syncComplete'.tr(namedArgs: {'count': '$count'}),
          ),
        ),
      );
    }
  }
}

class _FilterMenuItem extends StatelessWidget {
  const _FilterMenuItem({required this.label, required this.isSelected});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isSelected)
          const Icon(Icons.check, size: 18)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
