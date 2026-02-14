import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/event_repository.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==========================================
// 狀態模型
// ==========================================

/// 事件類型枚舉
enum EventType {
  exDividend('EX_DIVIDEND'),
  exRights('EX_RIGHTS'),
  earnings('EARNINGS'),
  custom('CUSTOM');

  const EventType(this.value);
  final String value;

  static EventType fromValue(String v) {
    return EventType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => EventType.custom,
    );
  }

  String get i18nKey {
    switch (this) {
      case EventType.exDividend:
        return 'calendar.typeExDividend';
      case EventType.exRights:
        return 'calendar.typeExRights';
      case EventType.earnings:
        return 'calendar.typeEarnings';
      case EventType.custom:
        return 'calendar.typeCustom';
    }
  }
}

/// 日曆篩選模式
enum CalendarFilter { all, watchlistOnly, portfolioOnly }

/// 行事曆狀態
class EventCalendarState {
  const EventCalendarState({
    this.focusedMonth,
    this.selectedDate,
    this.events = const {},
    this.selectedDayEvents = const [],
    this.filter = CalendarFilter.all,
    this.isLoading = false,
    this.error,
  });

  final DateTime? focusedMonth;
  final DateTime? selectedDate;

  /// 月事件 map（日期 → 事件列表），用於顯示日曆上的 dot indicators
  final Map<DateTime, List<StockEventEntry>> events;

  /// 選取日期的事件列表
  final List<StockEventEntry> selectedDayEvents;

  /// 篩選模式
  final CalendarFilter filter;

  final bool isLoading;
  final String? error;

  EventCalendarState copyWith({
    DateTime? focusedMonth,
    DateTime? selectedDate,
    Map<DateTime, List<StockEventEntry>>? events,
    List<StockEventEntry>? selectedDayEvents,
    CalendarFilter? filter,
    bool? isLoading,
    Object? error = sentinel,
  }) {
    return EventCalendarState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      events: events ?? this.events,
      selectedDayEvents: selectedDayEvents ?? this.selectedDayEvents,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error == sentinel ? this.error : error as String?,
    );
  }
}

// ==========================================
// Notifier
// ==========================================

class EventCalendarNotifier extends StateNotifier<EventCalendarState> {
  EventCalendarNotifier({
    required EventRepository eventRepository,
    required AppDatabase database,
    required AppClock clock,
  }) : _repo = eventRepository,
       _db = database,
       _clock = clock,
       super(const EventCalendarState());

  final EventRepository _repo;
  final AppDatabase _db;
  final AppClock _clock;

  /// 初始化：設定焦點月份為當月，載入事件
  Future<void> init() async {
    final now = _clock.now();
    final focused = DateTime(now.year, now.month);
    state = state.copyWith(focusedMonth: focused, selectedDate: now);
    await loadMonthEvents(focused);
    _updateSelectedDayEvents(now);
  }

  /// 載入某月的事件
  Future<void> loadMonthEvents(DateTime month) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(
        month.year,
        month.month + 1,
        0,
        23,
        59,
        59,
        999,
        999,
      );

      // 根據篩選取得 symbol 清單
      List<String>? filterSymbols;
      if (state.filter == CalendarFilter.watchlistOnly) {
        final watchlist = await _db.getWatchlist();
        filterSymbols = watchlist.map((e) => e.symbol).toList();
      } else if (state.filter == CalendarFilter.portfolioOnly) {
        final positions = await _db.getPortfolioPositions();
        filterSymbols = positions.map((e) => e.symbol).toList();
      }

      final eventList = await _repo.getEventsInRange(
        start,
        end,
        symbols: filterSymbols,
      );

      // 按日期分組（table_calendar 需要 normalize 到日期 key）
      final eventMap = <DateTime, List<StockEventEntry>>{};
      for (final event in eventList) {
        final dateKey = _normalizeDate(event.eventDate);
        eventMap.putIfAbsent(dateKey, () => []).add(event);
      }

      state = state.copyWith(
        focusedMonth: month,
        events: eventMap,
        isLoading: false,
        error: null,
      );

      // 更新選取日的事件
      if (state.selectedDate != null) {
        _updateSelectedDayEvents(state.selectedDate!);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 選取日期
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    _updateSelectedDayEvents(date);
  }

  /// 切換篩選模式
  Future<void> setFilter(CalendarFilter filter) async {
    state = state.copyWith(filter: filter);
    if (state.focusedMonth != null) {
      await loadMonthEvents(state.focusedMonth!);
    }
  }

  /// 新增自訂事件
  Future<void> addEvent({
    String? symbol,
    required DateTime eventDate,
    required String title,
    String? description,
  }) async {
    await _repo.addCustomEvent(
      symbol: symbol,
      eventDate: eventDate,
      title: title,
      description: description,
    );
    // 重新載入當月事件
    if (state.focusedMonth != null) {
      await loadMonthEvents(state.focusedMonth!);
    }
  }

  /// 刪除事件
  Future<void> deleteEvent(int id) async {
    await _repo.deleteEvent(id);
    if (state.focusedMonth != null) {
      await loadMonthEvents(state.focusedMonth!);
    }
  }

  /// 同步除權息事件
  Future<int> syncDividendEvents() async {
    final count = await _repo.syncDividendEvents();
    if (state.focusedMonth != null) {
      await loadMonthEvents(state.focusedMonth!);
    }
    return count;
  }

  void _updateSelectedDayEvents(DateTime date) {
    final dateKey = _normalizeDate(date);
    final dayEvents = state.events[dateKey] ?? [];
    state = state.copyWith(selectedDayEvents: dayEvents);
  }

  /// 將 DateTime 正規化為只有日期的 key（table_calendar 比較用）
  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

// ==========================================
// Providers
// ==========================================

final eventCalendarProvider =
    StateNotifierProvider<EventCalendarNotifier, EventCalendarState>((ref) {
      return EventCalendarNotifier(
        eventRepository: ref.watch(eventRepositoryProvider),
        database: ref.watch(databaseProvider),
        clock: ref.watch(appClockProvider),
      );
    });
