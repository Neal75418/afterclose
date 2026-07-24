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

  /// 雙欄（桌面）：左欄月曆＋篩選（flex 3、surface 卡定錨）、右欄
  /// 未來14天＋當日清單（flex 2、單一捲動——避免內層固定高把卡片腰斬）
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        // surface 卡片包月曆：裸月曆浮在黑底上沒有定錨、
                        // 兩側留白讀起來像破版（2026-07-24 使用者回饋）
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildCalendarSection(theme, state),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildRightPane(theme, state)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右欄：未來14天直列＋當日事件。
  ///
  /// 有清單資料時合併為單一 ListView 捲動（避免內層固定高腰斬卡片）；
  /// placeholder 態（載入／空／錯誤）改 Column＋Expanded 給彈性高度，
  /// EmptyStates 的按鈕在固定小盒裡會垂直 overflow。
  Widget _buildRightPane(ThemeData theme, EventCalendarState state) {
    final placeholder = _buildDayEventsPlaceholder(theme, state);
    if (placeholder != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUpcoming(state, direction: Axis.vertical),
          const Divider(height: 17),
          Expanded(child: placeholder),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _buildUpcoming(state, direction: Axis.vertical),
        const Divider(height: 17),
        for (final event in state.selectedDayEvents)
          EventListTile(
            event: event,
            onTap: () => showEventDetailSheet(
              context,
              event,
              onDelete: event.isAutoGenerated
                  ? null
                  : () => _confirmDelete(event),
            ),
            onDelete: () => _confirmDelete(event),
          ),
      ],
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

  /// 錯誤／載入／空三態 placeholder；有清單資料時回 null
  Widget? _buildDayEventsPlaceholder(
    ThemeData theme,
    EventCalendarState state,
  ) {
    if (state.error != null && state.events.isEmpty) {
      return ErrorDisplay.isNetworkError(state.error!)
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
            );
    }
    if (state.isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.selectedDayEvents.isEmpty) {
      return Center(
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
      );
    }
    return null;
  }

  /// 選取日期的事件列表（單欄用；placeholder 態或自捲清單）
  Widget _buildDayEventsBody(ThemeData theme, EventCalendarState state) {
    return _buildDayEventsPlaceholder(theme, state) ??
        ListView.builder(
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
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: EventType.values.map((type) {
          final selected = state.selectedEventTypes.contains(type);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(type.i18nKey.tr()),
              selected: selected,
              onSelected: (_) {
                ref.read(eventCalendarProvider.notifier).toggleEventType(type);
              },
              // 兩態皆中性、類型色只留 8px 色點：預設五類全選時，著色
              // label/avatar 會讓整排恆常呈彩虹（2026-07-24 使用者回饋）。
              // 選中與否由底色＋勾勾表達。
              selectedColor: theme.colorScheme.surfaceContainerHighest,
              checkmarkColor: theme.colorScheme.onSurface,
              avatar: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: type.colorFor(brightness),
                  shape: BoxShape.circle,
                ),
              ),
              labelStyle: const TextStyle(fontSize: 12),
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
