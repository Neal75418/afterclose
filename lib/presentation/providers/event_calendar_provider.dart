import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/event_repository.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// 狀態模型
// ==================================================

/// 事件類型枚舉
enum EventType {
  exDividend('EX_DIVIDEND'),
  exRights('EX_RIGHTS'),
  earnings('EARNINGS'),
  shareholderMeeting('SHAREHOLDER_MEETING'),
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
      case EventType.shareholderMeeting:
        return 'calendar.typeMeeting';
      case EventType.custom:
        return 'calendar.typeCustom';
    }
  }

  Color get color {
    switch (this) {
      case EventType.exDividend:
        return Colors.red;
      case EventType.exRights:
        return Colors.orange;
      case EventType.earnings:
        return Colors.green;
      case EventType.shareholderMeeting:
        return Colors.purple;
      case EventType.custom:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.exDividend:
        return Icons.payments_outlined;
      case EventType.exRights:
        return Icons.inventory_2_outlined;
      case EventType.earnings:
        return Icons.article_outlined;
      case EventType.shareholderMeeting:
        return Icons.groups_outlined;
      case EventType.custom:
        return Icons.edit_note;
    }
  }
}

/// 日曆篩選模式
enum CalendarFilter { all, watchlistOnly, portfolioOnly }

/// 行事曆狀態
class EventCalendarState {
  EventCalendarState({
    this.focusedMonth,
    this.selectedDate,
    this.events = const {},
    this.selectedDayEvents = const [],
    this.upcomingEvents = const [],
    this.filter = CalendarFilter.all,
    Set<EventType>? selectedEventTypes,
    this.calendarFormat = CalendarFormat.month,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
  }) : selectedEventTypes = selectedEventTypes ?? EventType.values.toSet();

  final DateTime? focusedMonth;
  final DateTime? selectedDate;

  /// 月事件 map（日期 → 事件列表），用於顯示日曆上的 dot indicators
  final Map<DateTime, List<StockEventEntry>> events;

  /// 選取日期的事件列表
  final List<StockEventEntry> selectedDayEvents;

  /// 未來 14 天的即將到來事件
  final List<StockEventEntry> upcomingEvents;

  /// 篩選模式
  final CalendarFormat calendarFormat;

  final CalendarFilter filter;

  /// 選取的事件類型（用於類型篩選）
  final Set<EventType> selectedEventTypes;

  final bool isLoading;

  /// 是否正在同步（防止連續點擊）
  final bool isSyncing;

  final String? error;

  /// 根據 selectedEventTypes 過濾後的事件 map
  Map<DateTime, List<StockEventEntry>> get filteredEvents {
    if (selectedEventTypes.length == EventType.values.length) return events;
    final filtered = <DateTime, List<StockEventEntry>>{};
    for (final entry in events.entries) {
      final list = entry.value
          .where(
            (e) =>
                selectedEventTypes.contains(EventType.fromValue(e.eventType)),
          )
          .toList();
      if (list.isNotEmpty) filtered[entry.key] = list;
    }
    return filtered;
  }

  EventCalendarState copyWith({
    DateTime? focusedMonth,
    DateTime? selectedDate,
    Map<DateTime, List<StockEventEntry>>? events,
    List<StockEventEntry>? selectedDayEvents,
    List<StockEventEntry>? upcomingEvents,
    CalendarFilter? filter,
    Set<EventType>? selectedEventTypes,
    CalendarFormat? calendarFormat,
    bool? isLoading,
    bool? isSyncing,
    Object? error = sentinel,
  }) {
    return EventCalendarState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      events: events ?? this.events,
      selectedDayEvents: selectedDayEvents ?? this.selectedDayEvents,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      filter: filter ?? this.filter,
      selectedEventTypes: selectedEventTypes ?? this.selectedEventTypes,
      calendarFormat: calendarFormat ?? this.calendarFormat,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error == sentinel ? this.error : error as String?,
    );
  }
}

// ==================================================
// Notifier
// ==================================================

class EventCalendarNotifier extends Notifier<EventCalendarState> {
  late final EventRepository _repo;
  late final AppDatabase _db;
  late final AppClock _clock;

  @override
  EventCalendarState build() {
    _repo = ref.watch(eventRepositoryProvider);
    _db = ref.watch(databaseProvider);
    _clock = ref.watch(appClockProvider);
    return EventCalendarState();
  }

  /// 初始化：設定焦點月份為當月，載入事件
  Future<void> init() async {
    final now = _clock.now();
    final focused = DateTime(now.year, now.month);
    state = state.copyWith(focusedMonth: focused, selectedDate: now);
    await loadMonthEvents(focused);
    _updateSelectedDayEvents(now);
    await _loadUpcomingEvents();
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
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
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

  /// 儲存日曆格式偏好
  void setCalendarFormat(CalendarFormat format) {
    state = state.copyWith(calendarFormat: format);
  }

  /// 切換事件類型篩選
  void toggleEventType(EventType type) {
    final current = Set<EventType>.from(state.selectedEventTypes);
    if (current.contains(type)) {
      // 至少保留一種類型
      if (current.length > 1) current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(selectedEventTypes: current);
    if (state.selectedDate != null) {
      _updateSelectedDayEvents(state.selectedDate!);
    }
  }

  /// 新增自訂事件
  ///
  /// 寫入成功後重載當月事件；若重載失敗會拋出例外，
  /// 讓呼叫端知道資料可能未同步（寫入本身已完成）。
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
      // loadMonthEvents 吞掉例外只寫 state.error，
      // 但呼叫端需要知道重載失敗才能給正確回饋
      if (state.error != null) {
        throw StateError(state.error!);
      }
    }
  }

  /// 刪除事件
  ///
  /// 寫入成功後重載當月事件；若重載失敗會拋出例外。
  Future<void> deleteEvent(int id) async {
    await _repo.deleteEvent(id);
    if (state.focusedMonth != null) {
      await loadMonthEvents(state.focusedMonth!);
      if (state.error != null) {
        throw StateError(state.error!);
      }
    }
  }

  /// 同步除權息事件
  ///
  /// 與 [addEvent]/[deleteEvent] 不同，此方法回傳結果 record 供 UI 顯示，
  /// 重載失敗時 state.error 已被設定，呼叫端可據此顯示警告而不影響 record 結果。
  Future<({int exDividend, int exRights, int total})>
  syncDividendEvents() async {
    if (state.isSyncing) return (exDividend: 0, exRights: 0, total: 0);
    state = state.copyWith(isSyncing: true);
    try {
      final result = await _repo.syncDividendEvents();
      if (state.focusedMonth != null) {
        await loadMonthEvents(state.focusedMonth!);
      }
      await _loadUpcomingEvents();
      return result;
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  /// 載入近期事件
  ///
  /// 失敗時寫入 [state.error]，讓呼叫端（如 syncDividendEvents）
  /// 可據此向 UI 顯示警告。
  Future<void> _loadUpcomingEvents() async {
    try {
      final now = _clock.now();
      final today = DateTime(now.year, now.month, now.day);
      final end = today.add(
        const Duration(days: DataFreshness.upcomingEventsDays),
      );
      final events = await _repo.getEventsInRange(today, end);
      state = state.copyWith(upcomingEvents: events);
    } catch (e) {
      AppLogger.warning('EventCalendarNotifier', '載入近期事件失敗', e);
      // 僅在尚無錯誤時寫入，避免覆蓋 loadMonthEvents 等更重要的錯誤
      if (state.error == null) {
        state = state.copyWith(error: ErrorDisplay.message(e));
      }
    }
  }

  void _updateSelectedDayEvents(DateTime date) {
    final dateKey = _normalizeDate(date);
    final dayEvents = state.filteredEvents[dateKey] ?? [];
    state = state.copyWith(selectedDayEvents: dayEvents);
  }

  /// 將 DateTime 正規化為只有日期的 key（table_calendar 比較用）
  static DateTime _normalizeDate(DateTime date) {
    return DateContext.normalize(date);
  }
}

// ==================================================
// Providers
// ==================================================

final eventCalendarProvider =
    NotifierProvider<EventCalendarNotifier, EventCalendarState>(
      EventCalendarNotifier.new,
    );
