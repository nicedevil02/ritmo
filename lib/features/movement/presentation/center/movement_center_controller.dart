import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// ۸ حالت ورود مرکز حرکت (Matrix of 8 Entry States)
enum MovementCenterEntryState {
  brandNewUser,
  hasPlanTodaySession,
  todaySessionCompleted,
  pastPlannedTime,
  multiSessionsToday,
  recoveryDay,
  inProgressLiveSession,
  firstLaunchAfterCutover,
}

class MovementCenterController extends ChangeNotifier {
  MovementCenterController({
    required this.occurrenceService,
    required this.sessionService,
    required this.strengthProgramService,
    DateTime? initialDate,
    this.isFirstLaunchAfterCutover = false,
  }) {
    final now = initialDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekStartDate = _getSaturdayOfWeek(_selectedDate);
    _weekEndDate = _weekStartDate.add(const Duration(days: 6));
    _weekDays = _buildDaysForWeek(_weekStartDate, _selectedDate, const {});
  }

  final MovementOccurrenceService occurrenceService;
  final MovementSessionService sessionService;
  final StrengthProgramService strengthProgramService;

  late DateTime _selectedDate;
  late DateTime _weekStartDate;
  late DateTime _weekEndDate;

  bool _isLoading = true;
  bool _hasCachedData = false;
  String? _errorMessage;
  bool _isBannerError = false;

  bool isFirstLaunchAfterCutover;

  DateTime get selectedDate => _selectedDate;
  DateTime get weekStartDate => _weekStartDate;
  DateTime get weekEndDate => _weekEndDate;
  bool get isLoading => _isLoading;
  bool get hasCachedData => _hasCachedData;
  String? get errorMessage => _errorMessage;
  bool get isBannerError => _isBannerError;

  bool get isCurrentWeek {
    final now = DateTime.now();
    final todaySat = _getSaturdayOfWeek(now);
    return _weekStartDate.year == todaySat.year &&
        _weekStartDate.month == todaySat.month &&
        _weekStartDate.day == todaySat.day;
  }

  String get weekRangeLabel {
    final startJalali = Jalali.fromDateTime(_weekStartDate);
    final endJalali = Jalali.fromDateTime(_weekEndDate);
    if (startJalali.month == endJalali.month) {
      return '${toPersianDigits(startJalali.day)} تا ${toPersianDigits(endJalali.day)} ${startJalali.formatter.mN}';
    }
    return '${toPersianDigits(startJalali.day)} ${startJalali.formatter.mN} تا ${toPersianDigits(endJalali.day)} ${endJalali.formatter.mN}';
  }

  List<MovementDayData> _weekDays = [];
  List<MovementDayData> get weekDays => _weekDays;

  Map<String, List<MovementOccurrence>> _weekOccurrencesMap = {};
  Map<String, List<MovementOccurrence>> get weekOccurrencesMap => _weekOccurrencesMap;

  List<MovementOccurrence> get selectedDayOccurrences {
    final key = _formatDateIso(_selectedDate);
    return _weekOccurrencesMap[key] ?? const [];
  }

  MovementLiveSession? _activeLiveSession;
  MovementLiveSession? get activeLiveSession => _activeLiveSession;

  MovementStrengthProgram? _strengthProgram;
  MovementStrengthProgram? get strengthProgram => _strengthProgram;

  MovementWeekSummary _weekSummary = const MovementWeekSummary();
  MovementWeekSummary get weekSummary => _weekSummary;

  HeroCardVariant _heroVariant = HeroCardVariant.emptyPlan;
  HeroCardVariant get heroVariant => _heroVariant;

  MovementCenterEntryState _entryState = MovementCenterEntryState.brandNewUser;
  MovementCenterEntryState get entryState => _entryState;

  static DateTime _getSaturdayOfWeek(DateTime date) {
    final daysSinceSaturday = (date.weekday - 6 + 7) % 7;
    final sat = date.subtract(Duration(days: daysSinceSaturday));
    return DateTime(sat.year, sat.month, sat.day);
  }

  static String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static List<MovementDayData> _buildDaysForWeek(
    DateTime weekStartDate,
    DateTime selectedDate,
    Map<String, List<MovementOccurrence>> occurrencesMap,
  ) {
    final List<MovementDayData> days = [];
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    const dayShortNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    for (int i = 0; i < 7; i++) {
      final d = weekStartDate.add(Duration(days: i));
      final dateIso = _formatDateIso(d);

      final jDate = Jalali.fromDateTime(d);
      final isToday = d.year == todayDate.year &&
          d.month == todayDate.month &&
          d.day == todayDate.day;
      final isSelected = d.year == selectedDate.year &&
          d.month == selectedDate.month &&
          d.day == selectedDate.day;

      MovementDaySlotState state;
      if (isToday && isSelected) {
        state = MovementDaySlotState.todayAndSelected;
      } else if (isSelected) {
        state = MovementDaySlotState.selected;
      } else if (isToday) {
        state = MovementDaySlotState.today;
      } else {
        state = MovementDaySlotState.normal;
      }

      final occurrencesForDay = occurrencesMap[dateIso] ?? const [];
      final statuses = occurrencesForDay.map<MovementDayStatus>((occ) {
        return switch (occ.status) {
          MovementOccurrenceStatus.completed => MovementDayStatus.completed,
          MovementOccurrenceStatus.partial => MovementDayStatus.partial,
          MovementOccurrenceStatus.moved => MovementDayStatus.moved,
          _ => MovementDayStatus.planned,
        };
      }).toList();

      final completedCount =
          occurrencesForDay.where((o) => o.isCompleted).length;

      days.add(MovementDayData(
        date: d,
        dayName: dayShortNames[i],
        dayNumber: jDate.day,
        monthName: jDate.formatter.mN,
        state: state,
        statuses: statuses,
        sessionCount: occurrencesForDay.length,
        completedCount: completedCount,
      ));
    }
    return days;
  }

  void dismissCutoverCallout() {
    isFirstLaunchAfterCutover = false;
    notifyListeners();
  }

  Future<void> loadData({bool isRefresh = false}) async {
    if (!isRefresh && !_hasCachedData) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final startIso = _formatDateIso(_weekStartDate);
      final endIso = _formatDateIso(_weekEndDate);

      // ۱. رخدادهای هفته
      _weekOccurrencesMap = await occurrenceService.getWeekOccurrencesGrouped(
        startIso,
        endIso,
      );

      // ۲. جلسهٔ زنده
      _activeLiveSession = await sessionService.getActiveOrPausedSession();

      // ۳. برنامهٔ قدرتی
      _strengthProgram = await strengthProgramService.getCurrentProgram();

      // ۴. ساخت اسلات‌های ۷ روز
      final allSevenDaysIso = List.generate(
        7,
        (i) => _formatDateIso(_weekStartDate.add(Duration(days: i))),
      );
      _weekDays = _buildDaysForWeek(_weekStartDate, _selectedDate, _weekOccurrencesMap);

      // ۵. محاسبه خلاصه هفته
      _weekSummary = await occurrenceService.getWeekSummary(
        startIso,
        endIso,
        allSevenDaysIso,
      );

      // ۶. محاسبه حالت هیرو و Entry State
      _computeEntryStateAndHero();

      MovementAnalyticsService.instance.logCenterOpened(
        source: 'movement_center',
        hasPlan: _entryState != MovementCenterEntryState.brandNewUser,
        heroState: _heroVariant.name,
      );

      _hasCachedData = true;
      _errorMessage = null;
      _isBannerError = false;
    } catch (e) {
      if (_hasCachedData) {
        _isBannerError = true;
        _errorMessage = e.toString();
      } else {
        _isBannerError = false;
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _computeEntryStateAndHero() {
    final now = _selectedDate;
    final todayIso = _formatDateIso(now);
    final todayOccurrences = _weekOccurrencesMap[todayIso] ?? const [];
    final selectedOccurrences = selectedDayOccurrences;
    final totalWeekOccurrences =
        _weekOccurrencesMap.values.fold<int>(0, (sum, list) => sum + list.length);

    // حالت ۷: جلسه زنده در حال انجام
    if (_activeLiveSession != null && _activeLiveSession!.isActiveOrPaused) {
      _entryState = MovementCenterEntryState.inProgressLiveSession;
    }
    // حالت ۸: اولین اجرا پس از Cutover
    else if (isFirstLaunchAfterCutover && totalWeekOccurrences == 0) {
      _entryState = MovementCenterEntryState.firstLaunchAfterCutover;
    }
    // حالت ۱: کاربر کاملاً جدید
    else if (totalWeekOccurrences == 0) {
      _entryState = MovementCenterEntryState.brandNewUser;
    }
    // امروز جلسه‌ای ندارد اما هفته جلسه دارد (روز ریکاوری)
    else if (todayOccurrences.isEmpty && _selectedDate.day == now.day && _selectedDate.month == now.month) {
      _entryState = MovementCenterEntryState.recoveryDay;
    }
    // امروز جلسه دارد
    else if (todayOccurrences.isNotEmpty) {
      final allCompleted = todayOccurrences.every((o) => o.isCompleted);
      final hasLate = todayOccurrences.any((o) => o.status == MovementOccurrenceStatus.late);

      if (allCompleted) {
        _entryState = MovementCenterEntryState.todaySessionCompleted;
      } else if (hasLate) {
        _entryState = MovementCenterEntryState.pastPlannedTime;
      } else if (todayOccurrences.length > 1) {
        _entryState = MovementCenterEntryState.multiSessionsToday;
      } else {
        _entryState = MovementCenterEntryState.hasPlanTodaySession;
      }
    } else {
      _entryState = MovementCenterEntryState.brandNewUser;
    }

    // تنظیم Hero Variant متناظر بر اساس روز انتخاب‌شده
    if (totalWeekOccurrences == 0) {
      _heroVariant = HeroCardVariant.emptyPlan;
    } else if (selectedOccurrences.isEmpty) {
      _heroVariant = HeroCardVariant.restDay;
    } else {
      final allDone = selectedOccurrences.every((o) => o.isCompleted);
      final hasLate = selectedOccurrences.any((o) => o.status == MovementOccurrenceStatus.late);
      if (allDone) {
        _heroVariant = HeroCardVariant.allDone;
      } else if (hasLate) {
        _heroVariant = HeroCardVariant.late;
      } else if (selectedOccurrences.length > 1) {
        _heroVariant = HeroCardVariant.multiToday;
      } else {
        _heroVariant = HeroCardVariant.ready;
      }
    }
  }

  void selectDay(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    // بازسازی وضعیت اسلات‌های هفته بدون درخواست دیتابیس (زیر ۱۰۰ میلی‌ثانیه از کش)
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    _weekDays = _weekDays.map((d) {
      final isToday = d.date.year == todayDate.year &&
          d.date.month == todayDate.month &&
          d.date.day == todayDate.day;
      final isSelected = d.date.year == _selectedDate.year &&
          d.date.month == _selectedDate.month &&
          d.date.day == _selectedDate.day;

      MovementDaySlotState state;
      if (isToday && isSelected) {
        state = MovementDaySlotState.todayAndSelected;
      } else if (isSelected) {
        state = MovementDaySlotState.selected;
      } else if (isToday) {
        state = MovementDaySlotState.today;
      } else {
        state = MovementDaySlotState.normal;
      }

      return MovementDayData(
        date: d.date,
        dayName: d.dayName,
        dayNumber: d.dayNumber,
        monthName: d.monthName,
        state: state,
        statuses: d.statuses,
        sessionCount: d.sessionCount,
        completedCount: d.completedCount,
      );
    }).toList();

    _computeEntryStateAndHero();
    notifyListeners();
  }

  void changeWeek(int deltaWeeks) {
    _weekStartDate = _weekStartDate.add(Duration(days: deltaWeeks * 7));
    _weekEndDate = _weekStartDate.add(const Duration(days: 6));
    // حفظ روز هفته انتخابی
    final dayOfWeekOffset = (_selectedDate.weekday - 6 + 7) % 7;
    _selectedDate = _weekStartDate.add(Duration(days: dayOfWeekOffset));
    loadData();
  }

  void goToThisWeek() {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekStartDate = _getSaturdayOfWeek(_selectedDate);
    _weekEndDate = _weekStartDate.add(const Duration(days: 6));
    loadData();
  }

  Future<void> refresh() async {
    await loadData(isRefresh: true);
  }

  /// تکمیل خوش‌بینانه با بازگشت در شکست
  Future<bool> optimisticCompleteOccurrence(String occurrenceId) async {
    final dateKey = _formatDateIso(_selectedDate);
    final occurrences = _weekOccurrencesMap[dateKey];
    if (occurrences == null) return false;

    final index = occurrences.indexWhere((o) => o.id == occurrenceId);
    if (index == -1) return false;

    final previousStatus = occurrences[index].status;
    // ۱. اعمال فوری در UI
    occurrences[index] = occurrences[index].copyWith(
      status: MovementOccurrenceStatus.completed,
    );
    _computeEntryStateAndHero();
    notifyListeners();

    try {
      // ۲. ذخیره در دیتابیس
      await occurrenceService.updateOccurrenceStatus(
        occurrenceId,
        MovementOccurrenceStatus.completed,
      );
      return true;
    } catch (e) {
      // ۳. بازگشت در صورت شکست
      occurrences[index] = occurrences[index].copyWith(
        status: previousStatus,
      );
      _computeEntryStateAndHero();
      notifyListeners();
      return false;
    }
  }

  Future<bool> optimisticSkipOccurrence(String occurrenceId) async {
    final dateKey = _formatDateIso(_selectedDate);
    final occurrences = _weekOccurrencesMap[dateKey];
    if (occurrences == null) return false;

    final index = occurrences.indexWhere((o) => o.id == occurrenceId);
    if (index == -1) return false;

    final previousStatus = occurrences[index].status;
    occurrences[index] = occurrences[index].copyWith(
      status: MovementOccurrenceStatus.skipped,
    );
    _computeEntryStateAndHero();
    notifyListeners();

    try {
      await occurrenceService.updateOccurrenceStatus(
        occurrenceId,
        MovementOccurrenceStatus.skipped,
      );
      return true;
    } catch (e) {
      occurrences[index] = occurrences[index].copyWith(
        status: previousStatus,
      );
      _computeEntryStateAndHero();
      notifyListeners();
      return false;
    }
  }
}
