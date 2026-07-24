import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/event_calendar_provider.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/add_event_sheet.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/event_detail_sheet.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/event_list_tile.dart';
import 'package:afterclose/presentation/screens/calendar/widgets/upcoming_events_section.dart';

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
          if (state.isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncDividendEvents,
              tooltip: 'calendar.syncDividendEvents'.tr(),
            ),
        ],
      ),
      // 響應式：≥ tablet 斷點雙欄（月曆左、未來14天＋當日事件右），
      // 空間用起來、不再是置中浮島；窄視窗維持單欄。兩者皆置中限寬。
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= Breakpoints.tablet;
          return isWide
              ? _buildWideBody(theme, state)
              : _buildNarrowBody(theme, state);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEvent(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 單欄（手機／窄視窗）：未來14天橫向卡 → 月曆＋篩選 → 當日清單
  Widget _buildNarrowBody(ThemeData theme, EventCalendarState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.contentMaxWidth,
        ),
        child: Column(
          children: [
            _buildUpcoming(state, direction: Axis.horizontal),
            _buildCalendarSection(theme, state),
            if (state.error != null && state.events.isNotEmpty)
              _buildErrorBanner(state),
            Expanded(child: _buildDayEventsBody(theme, state)),
          ],
        ),
      ),
    );
  }

  /// 雙欄（桌面）：左欄月曆＋篩選（flex 3）、右欄未來14天＋當日清單（flex 2）
  Widget _buildWideBody(ThemeData theme, EventCalendarState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.contentMaxWidthWide,
        ),
        child: Column(
          children: [
            if (state.error != null && state.events.isNotEmpty)
              _buildErrorBanner(state),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: _buildCalendarSection(theme, state),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUpcoming(state, direction: Axis.vertical),
                        const Divider(height: 1),
                        Expanded(child: _buildDayEventsBody(theme, state)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcoming(EventCalendarState state, {required Axis direction}) {
    return UpcomingEventsSection(
      events: state.upcomingEvents,
      direction: direction,
      onEventTap: (event) {
        setState(() {
          _selectedDay = event.eventDate;
          _focusedDay = event.eventDate;
        });
        ref.read(eventCalendarProvider.notifier).selectDate(event.eventDate);
        ref
            .read(eventCalendarProvider.notifier)
            .loadMonthEvents(
              DateTime(event.eventDate.year, event.eventDate.month),
            );
      },
    );
  }

  /// 月曆＋分隔線＋類型篩選 chips（單欄／雙欄共用）
  Widget _buildCalendarSection(ThemeData theme, EventCalendarState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TableCalendar<StockEventEntry>(
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: state.calendarFormat,
          // 取代套件英文預設（'Month'/'2 weeks'/'Week'）；按鈕顯示的是
          // 「下一個」格式的 label（formatButtonShowsNext 預設 true）。
          availableCalendarFormats: {
            CalendarFormat.month: 'calendar.formatMonth'.tr(),
            CalendarFormat.twoWeeks: 'calendar.formatTwoWeeks'.tr(),
            CalendarFormat.week: 'calendar.formatWeek'.tr(),
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: (day) {
            final dateKey = DateContext.normalize(day);
            return state.filteredEvents[dateKey] ?? [];
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            ref.read(eventCalendarProvider.notifier).selectDate(selectedDay);
          },
          onFormatChanged: (format) {
            ref.read(eventCalendarProvider.notifier).setCalendarFormat(format);
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
              return _buildEventMarkers(context, events);
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
        _buildEventTypeFilterChips(state),
      ],
    );
  }

  /// Refresh 失敗但有舊資料時的 MaterialBanner
  Widget _buildErrorBanner(EventCalendarState state) {
    return MaterialBanner(
      content: Text(state.error!),
      actions: [
        TextButton(
          onPressed: () {
            if (state.focusedMonth != null) {
              ref
                  .read(eventCalendarProvider.notifier)
                  .loadMonthEvents(state.focusedMonth!);
            }
          },
          child: Text('common.retry'.tr()),
        ),
        TextButton(
          onPressed: () =>
              ref.read(eventCalendarProvider.notifier).clearError(),
          child: Text('common.dismiss'.tr()),
        ),
      ],
    );
  }

  /// 選取日期的事件列表（錯誤／載入／空／清單四態）
  Widget _buildDayEventsBody(ThemeData theme, EventCalendarState state) {
    return state.error != null && state.events.isEmpty
        ? ErrorDisplay.isNetworkError(state.error!)
              ? EmptyStates.networkError(
                  onRetry: () {
                    if (state.focusedMonth != null) {
                      ref
                          .read(eventCalendarProvider.notifier)
                          .loadMonthEvents(state.focusedMonth!);
                    }
                  },
                )
              : EmptyStates.error(
                  message: state.error!,
                  onRetry: () {
                    if (state.focusedMonth != null) {
                      ref
                          .read(eventCalendarProvider.notifier)
                          .loadMonthEvents(state.focusedMonth!);
                    }
                  },
                )
        : state.isLoading
        ? const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : state.selectedDayEvents.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 48,
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
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
                onTap: () => showEventDetailSheet(
                  context,
                  event,
                  onDelete: event.isAutoGenerated
                      ? null
                      : () => _confirmDelete(event),
                ),
                onDelete: () => _confirmDelete(event),
              );
            },
          );
  }

  Widget _buildEventTypeFilterChips(EventCalendarState state) {
    final brightness = Theme.of(context).brightness;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: EventType.values.map((type) {
          final selected = state.selectedEventTypes.contains(type);
          final onTint = type.onTintFor(brightness);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(type.i18nKey.tr()),
              selected: selected,
              onSelected: (_) {
                ref.read(eventCalendarProvider.notifier).toggleEventType(type);
              },
              // tint 底維持 .color、alpha 對齊守門測試組合（0.15）
              selectedColor: type.color.withValues(alpha: 0.15),
              checkmarkColor: onTint,
              // 未選中＝中性：小色點保留類型識別、其餘灰階，消掉整排糖果感
              avatar: selected
                  ? Icon(type.icon, size: 16, color: onTint)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: type.colorFor(brightness),
                        shape: BoxShape.circle,
                      ),
                    ),
              labelStyle: TextStyle(
                color: selected ? onTint : null,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventMarkers(
    BuildContext context,
    List<StockEventEntry> events,
  ) {
    final brightness = Theme.of(context).brightness;
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
              color: type.colorFor(brightness),
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
      constraints: const BoxConstraints(maxWidth: Breakpoints.sheetMaxWidth),
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
      try {
        await ref.read(eventCalendarProvider.notifier).deleteEvent(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('calendar.eventDeleted'.tr()),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'common.undo'.tr(),
                onPressed: () async {
                  try {
                    await ref
                        .read(eventCalendarProvider.notifier)
                        .addEvent(
                          symbol: event.symbol,
                          eventDate: event.eventDate,
                          title: event.title,
                          description: event.description,
                        );
                  } catch (_) {
                    // 還原失敗靜默處理（事件已刪除，重新建立可能失敗）
                  }
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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
  }

  Future<void> _syncDividendEvents() async {
    try {
      final notifier = ref.read(eventCalendarProvider.notifier);
      final result = await notifier.syncDividendEvents();
      if (mounted) {
        // syncDividendEvents 不 throw reload 失敗，但會設定 state.error
        final reloadError = ref.read(eventCalendarProvider).error;
        final message = 'calendar.syncDetailComplete'.tr(
          namedArgs: {
            'exDividend': '${result.exDividend}',
            'exRights': '${result.exRights}',
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reloadError != null ? '$message（$reloadError）' : message,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorDisplay.message(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
