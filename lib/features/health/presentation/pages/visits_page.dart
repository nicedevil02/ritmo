import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_form_sheet.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_summary_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  int _activeTabIndex = 0;
  List<DoctorVisit> _upcomingVisits = [];
  List<DoctorVisit> _pastVisits = [];
  bool _isLoading = true;

  static const _monthNamesFa = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const _weekdayNamesFa = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  static const _templates = [
    (
      title: 'چکاپ عمومی',
      icon: '🩺',
      doctorName: '',
      specialty: 'پزشک عمومی',
      reason: 'چکاپ دوره‌ای سالانه و پایش سلامت عمومی',
    ),
    (
      title: 'دندان‌پزشکی',
      icon: '🦷',
      doctorName: '',
      specialty: 'دندان‌پزشک',
      reason: 'معاینه دوره‌ای دندان و جرم‌گیری',
    ),
    (
      title: 'چشم‌پزشکی',
      icon: '👁',
      doctorName: '',
      specialty: 'متخصص چشم',
      reason: 'معاینه بینایی و سنجش نمره چشم',
    ),
    (
      title: 'آزمایشگاه',
      icon: '🧪',
      doctorName: 'آزمایشگاه پاتوبیولوژی',
      specialty: 'آزمایشگاه تشخیص طبی',
      reason: 'آزمایش خون، چربی و قند خون ناشتا',
    ),
    (
      title: 'متخصص قلب',
      icon: '❤️',
      doctorName: '',
      specialty: 'متخصص قلب و عروق',
      reason: 'کنترل فشار خون و اکوکاردیوگرافی',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  String _getRelativeTimeLabel(int epochMs) {
    final now = DateTime.now();
    final visitDate = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final diff = visitDate.difference(now);

    if (diff.isNegative) {
      return 'سپری شده';
    }

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 60);
      return '${_toPersianDigits(mins.toString())} دقیقه دیگر';
    }

    final isToday = now.year == visitDate.year && now.month == visitDate.month && now.day == visitDate.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = tomorrow.year == visitDate.year && tomorrow.month == visitDate.month && tomorrow.day == visitDate.day;

    final hourStr = visitDate.hour.toString().padLeft(2, '0');
    final minStr = visitDate.minute.toString().padLeft(2, '0');
    final timeStr = _toPersianDigits('$hourStr:$minStr');

    if (isToday) {
      return 'امروز ساعت $timeStr';
    }
    if (isTomorrow) {
      return 'فردا ساعت $timeStr';
    }

    if (diff.inDays <= 7) {
      return '${_toPersianDigits(diff.inDays.toString())} روز مانده';
    }

    final weeks = diff.inDays ~/ 7;
    return '${_toPersianDigits(weeks.toString())} هفته مانده';
  }

  ({String monthName, String dayNumber, String weekdayName, String timeStr}) _getTicketDateData(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final j = Jalali.fromDateTime(dt);
    final monthIdx = (j.month - 1).clamp(0, 11);
    final monthName = _monthNamesFa[monthIdx];
    final dayNumber = _toPersianDigits(j.day.toString());
    final weekdayIdx = (j.weekDay - 1).clamp(0, 6);
    final weekdayName = _weekdayNamesFa[weekdayIdx];

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = _toPersianDigits('$hour:$minute');

    return (monthName: monthName, dayNumber: dayNumber, weekdayName: weekdayName, timeStr: timeStr);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('doctor_visits', orderBy: 'visitDateTime ASC');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final upcoming = <DoctorVisit>[];
      final past = <DoctorVisit>[];

      for (final map in results) {
        final visit = DoctorVisit.fromMap(map);
        if (visit.visitDateTime > nowMs && visit.status == 'UPCOMING') {
          upcoming.add(visit);
        } else {
          past.add(visit);
        }
      }

      past.sort((a, b) => b.visitDateTime.compareTo(a.visitDateTime));

      if (mounted) {
        setState(() {
          _upcomingVisits = upcoming;
          _pastVisits = past;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctor visits: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveVisit(DoctorVisit visit) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'doctor_visits',
        visit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final alarmId = 'visit_${visit.id}';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (visit.status == 'UPCOMING') {
        final reminderTime = visit.visitDateTime - (visit.reminderBefore * 60 * 1000);
        if (reminderTime > nowMs) {
          await db.insert(
            'pending_reminders',
            {
              'id': alarmId,
              'routineId': null,
              'scheduleId': null,
              'originalTime': reminderTime,
              'scheduledTime': reminderTime,
              'state': 'unknown',
              'deferCount': 0,
              'createdAt': nowMs,
              'updatedAt': nowMs,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await NotificationGateway.schedule(
            NotificationRequest(
              id: alarmId,
              channel: NotificationChannelId.critical,
              scheduledAt: DateTime.fromMillisecondsSinceEpoch(reminderTime),
              title: 'نوبت پزشک: ${visit.doctorName}',
              privacy: NotificationPrivacy.redacted,
              redactedTitle: 'ریتمو: یادآوری نوبت پزشک',
              sourceSystem: 'health',
              entityId: visit.id,
            ),
          );
          await SnapshotSyncService.syncAll();
        } else {
          await NotificationGateway.cancel(alarmId);
          await db.delete('pending_reminders', where: 'id = ?', whereArgs: [alarmId]);
        }
      } else {
        await NotificationGateway.cancel(alarmId);
        await db.delete('pending_reminders', where: 'id = ?', whereArgs: [alarmId]);
      }

      await _loadData();
    } catch (e) {
      debugPrint('Error saving visit: $e');
    }
  }

  Future<void> _deleteVisit(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('doctor_visits', where: 'id = ?', whereArgs: [id]);
      await NotificationGateway.cancel('visit_$id');
      await db.delete('pending_reminders', where: 'id = ?', whereArgs: ['visit_$id']);
      await SnapshotSyncService.syncAll();
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting visit: $e');
    }
  }

  Future<void> _updateVisitStatus(DoctorVisit visit, String newStatus) async {
    final updated = DoctorVisit(
      id: visit.id,
      doctorName: visit.doctorName,
      specialty: visit.specialty,
      clinicName: visit.clinicName,
      clinicAddress: visit.clinicAddress,
      clinicPhone: visit.clinicPhone,
      visitDateTime: visit.visitDateTime,
      visitType: visit.visitType,
      status: newStatus,
      reason: visit.reason,
      doctorNotes: visit.doctorNotes,
      userNotes: visit.userNotes,
      followUpDate: visit.followUpDate,
      reminderBefore: visit.reminderBefore,
      attachmentPath: visit.attachmentPath,
      createdAt: visit.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveVisit(updated);
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('امکان برقراری تماس با شماره $phone وجود ندارد.'),
            backgroundColor: context.colors.medicalRed,
          ),
        );
      }
    }
  }

  Future<void> _openMap(String? address) async {
    if (address == null || address.trim().isEmpty) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('امکان باز کردن نقشه وجود ندارد.')),
        );
      }
    }
  }

  void _showAttachmentViewer(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(path),
                  cacheWidth: 1080,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(32),
                    color: context.colors.card,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: context.colors.medicalRed, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'خطا در بارگذاری تصویر نسخه',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => Navigator.pop(context),
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                child: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddEditPage({DoctorVisit? visit}) async {
    final res = await DoctorVisitFormSheet.show(
      context,
      visit: visit,
      onSave: (saved) async {
        await _saveVisit(saved);
      },
    );
    if (res == true && mounted) {
      await _loadData();
    }
  }

  void _applyTemplate(
    ({
      String title,
      String icon,
      String doctorName,
      String specialty,
      String reason,
    }) template,
  ) {
    RitmoHaptics.selection();
    final now = DateTime.now();
    final defaultDateTime = DateTime(now.year, now.month, now.day + 2, 10, 0).millisecondsSinceEpoch;

    final templateVisit = DoctorVisit(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      doctorName: template.doctorName,
      specialty: template.specialty,
      visitDateTime: defaultDateTime,
      visitType: 'IN_PERSON',
      status: 'UPCOMING',
      reason: template.reason,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    _openAddEditPage(visit: templateVisit);
  }

  void _openDoctorVisitSummarySheet() {
    DoctorVisitSummarySheet.show(context);
  }

  Future<void> _confirmDelete(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final res = await RitmoGlassDialog.show(
      context,
      title: l10n.doctorVisitsDelete,
      content: l10n.doctorVisitsDeleteConfirm,
      confirmLabel: l10n.doctorVisitsConfirm,
      cancelLabel: l10n.doctorVisitsCancel,
      isDestructive: true,
      icon: CupertinoIcons.trash_fill,
    );
    if (res == true) {
      await _deleteVisit(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    final currentVisits = _activeTabIndex == 0 ? _upcomingVisits : _pastVisits;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: l10n.doctorVisits,
          showBackButton: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _openDoctorVisitSummarySheet,
                icon: Icon(CupertinoIcons.doc_text_fill, size: 14, color: colors.primary),
                label: Text(
                  'خلاصه برای پزشک',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ۱. نوار تب‌های شیشه‌ای تفکیک نوبت‌ها
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: RitmoGlassSegmentedControl<int>(
                selectedIndex: _activeTabIndex,
                accentColor: colors.primary,
                onTabChanged: (index) {
                  RitmoHaptics.selection();
                  setState(() {
                    _activeTabIndex = index;
                  });
                },
                items: [
                  RitmoTabItem<int>(
                    title: l10n.doctorVisitsTabUpcoming,
                    icon: CupertinoIcons.calendar_today,
                    value: 0,
                  ),
                  RitmoTabItem<int>(
                    title: l10n.doctorVisitsTabPast,
                    icon: CupertinoIcons.clock_fill,
                    value: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ۲. لیست نوبت‌ها همراه با ترنزیشن انیمیشنی روان (AnimatedSwitcher)
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_activeTabIndex),
                        child: currentVisits.isEmpty
                            ? _buildSmartEmptyState(_activeTabIndex == 1)
                            : _buildVisitsList(currentVisits, isPast: _activeTabIndex == 1),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: 50,
              child: RitmoNeuButton(
                onTap: () => _openAddEditPage(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add_circled_solid, color: colors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.doctorVisitsAddTitle,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── وضعیت خالی هوشمند با الگوهای آماده (Smart Empty State) ──
  Widget _buildSmartEmptyState(bool isPast) {
    final colors = context.colors;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          RitmoCard.neumorphic(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isPast ? CupertinoIcons.clock_fill : CupertinoIcons.calendar_badge_plus,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPast ? 'سابقه‌ای از نوبت‌های گذشته ثبت نشده است' : 'نوبت پزشکی پیش‌رویی ندارید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPast
                      ? 'سوابق نوبت‌های گذشته و توصیه‌های پزشک پس از اتمام زمان نوبت در این بخش آرشیو می‌شوند.'
                      : 'با ثبت نوبت‌های ویزیت، مشاوره یا آزمایش‌های پزشکی، ریتمو زمان مراجعه، مکان و نکات لازم را به شما یادآوری می‌کند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (!isPast) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 46,
                    child: RitmoNeuButton(
                      onTap: () => _openAddEditPage(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus_circle_fill, color: colors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ثبت نوبت دلخواه',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isPast) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'الگوهای سریع ثبت نوبت:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates.map((tpl) {
                return InkWell(
                  onTap: () => _applyTemplate(tpl),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tpl.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          tpl.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── ساخت لیست نوبت‌ها با تفکیک هیرو در تب نوبت‌های پیش‌رو ──
  Widget _buildVisitsList(List<DoctorVisit> visits, {required bool isPast}) {
    final colors = context.colors;

    if (!isPast && visits.isNotEmpty) {
      final heroVisit = visits.first;
      final otherVisits = visits.length > 1 ? visits.sublist(1) : <DoctorVisit>[];

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // کارت هیرو نوبت بعدی
          _buildHeroNextVisitCard(heroVisit),
          if (otherVisits.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(CupertinoIcons.calendar, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'سایر نوبت‌های پیش‌رو (${_toPersianDigits(otherVisits.length.toString())})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...otherVisits.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTicketVisitCard(v, isPast: false),
                )),
          ],
          const SizedBox(height: 16),
        ],
      );
    }

    return ListView.builder(
      itemCount: visits.length,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final visit = visits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTicketVisitCard(visit, isPast: isPast),
        );
      },
    );
  }

  // ── کارت هیرو نوبت بعدی با شمارش معکوس و اکشن‌های سریع ──
  Widget _buildHeroNextVisitCard(DoctorVisit visit) {
    final colors = context.colors;
    final relativeLabel = _getRelativeTimeLabel(visit.visitDateTime);
    final ticketData = _getTicketDateData(visit.visitDateTime);

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نوار بالایی هیرو با بج زمان معکوس و نوع ویزیت
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.bolt_fill, size: 13, color: colors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'نوبت بعدی شما • $relativeLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildVisitTypeBadge(visit.visitType),
            ],
          ),
          const SizedBox(height: 14),

          // نام پزشک و استامپ تقویمی در هیرو
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // استامپ تقویمی هیرو
              Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    Text(
                      ticketData.monthName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticketData.dayNumber,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticketData.timeStr,
                      style: TextStyle(fontSize: 10.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // مشخصات پزشک و تخصص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.doctorName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (visit.specialty != null && visit.specialty!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          visit.specialty!,
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'علت: ${visit.reason}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // اطلاعات درمانگاه، تلفن و آدرس
          if ((visit.clinicName != null && visit.clinicName!.isNotEmpty) ||
              (visit.clinicPhone != null && visit.clinicPhone!.isNotEmpty) ||
              (visit.clinicAddress != null && visit.clinicAddress!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            const RitmoCardDivider(),
            const SizedBox(height: 4),
            Row(
              children: [
                if (visit.clinicName != null && visit.clinicName!.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.building_2_fill, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            visit.clinicName!,
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (visit.clinicPhone != null && visit.clinicPhone!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _callPhone(visit.clinicPhone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.phone_fill, size: 13, color: colors.success),
                          const SizedBox(width: 4),
                          Text(
                            _toPersianDigits(visit.clinicPhone!),
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (visit.clinicAddress != null && visit.clinicAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openMap(visit.clinicAddress),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.location_solid, size: 14, color: colors.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        visit.clinicAddress!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // مشاهده مدرک و نسخه
          if (visit.attachmentPath != null && visit.attachmentPath!.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showAttachmentViewer(visit.attachmentPath!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.photo_fill, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'مشاهده نسخه و مدارک پیوست',
                      style: TextStyle(fontSize: 11.5, color: colors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const RitmoCardDivider(),
          const SizedBox(height: 6),

          // نوار دکمه‌های اقدام هیرو
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: RitmoNeuButton(
                    onTap: () {
                      RitmoHaptics.confirm();
                      _updateVisitStatus(visit, 'COMPLETED');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, size: 15, color: colors.success),
                        const SizedBox(width: 6),
                        Text(
                          'انجام شد',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.success),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: RitmoNeuButton(
                  onTap: () => _openAddEditPage(visit: visit),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.pencil, size: 15, color: colors.primary),
                      const SizedBox(width: 4),
                      Text('ویرایش', style: TextStyle(fontSize: 12, color: colors.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: RitmoNeuButton(
                  onTap: () => _confirmDelete(visit.id),
                  child: Icon(CupertinoIcons.trash, size: 15, color: colors.medicalRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── کارت بلیت‌مانند نوبت با استامپ تقویمی مدرن ──
  Widget _buildTicketVisitCard(DoctorVisit visit, {required bool isPast}) {
    final colors = context.colors;
    final ticketData = _getTicketDateData(visit.visitDateTime);

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // استامپ تقویمی (بلیت نوبت)
              Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isPast ? colors.textPrimary.withValues(alpha: 0.04) : colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPast ? colors.textPrimary.withValues(alpha: 0.08) : colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      ticketData.monthName,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isPast ? colors.textSecondary : colors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticketData.dayNumber,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isPast ? colors.textSecondary : colors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticketData.timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // مشخصات پزشک، تخصص و درمانگاه
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            visit.doctorName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isPast ? colors.textSecondary : colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildVisitTypeBadge(visit.visitType),
                      ],
                    ),
                    if (visit.specialty != null && visit.specialty!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        visit.specialty!,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                    if (visit.clinicName != null && visit.clinicName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(CupertinoIcons.building_2_fill, size: 13, color: colors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              visit.clinicName!,
                              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'علت: ${visit.reason}',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // بخش پایین کارت: اکشن‌های سریع و دکمه‌ها
          const SizedBox(height: 10),
          const RitmoCardDivider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // اکشن‌های ارتباطی (تماس / نسخه)
              Row(
                children: [
                  if (visit.clinicPhone != null && visit.clinicPhone!.isNotEmpty)
                    InkWell(
                      onTap: () => _callPhone(visit.clinicPhone),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.phone_fill, size: 11, color: colors.success),
                            const SizedBox(width: 3),
                            Text(
                              'تماس',
                              style: TextStyle(fontSize: 10.5, color: colors.success, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visit.attachmentPath != null && visit.attachmentPath!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showAttachmentViewer(visit.attachmentPath!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.photo_fill, size: 11, color: colors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'نسخه',
                              style: TextStyle(fontSize: 10.5, color: colors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // دکمه‌های کنترل
              Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.pencil, size: 16, color: colors.primary),
                    tooltip: 'ویرایش نوبت',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openAddEditPage(visit: visit),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.trash, size: 16, color: colors.medicalRed),
                    tooltip: 'حذف نوبت',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(visit.id),
                  ),
                  if (!isPast) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        RitmoHaptics.confirm();
                        _updateVisitStatus(visit, 'COMPLETED');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'انجام شد',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitTypeBadge(String type) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    var label = '';
    var color = colors.primary;

    switch (type) {
      case 'ONLINE':
        label = l10n.doctorVisitsTypeOnline;
        color = colors.warning;
      case 'TELEPHONE':
        label = l10n.doctorVisitsTypeTelephone;
        color = colors.success;
      case 'IN_PERSON':
      default:
        label = l10n.doctorVisitsTypeInPerson;
        color = colors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

