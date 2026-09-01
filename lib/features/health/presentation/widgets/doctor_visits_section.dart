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
import 'package:ritmo/core/widgets/ritmo/ritmo_glass_surface.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_form_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorVisitsSection extends StatefulWidget {
  const DoctorVisitsSection({
    super.key,
  });

  @override
  State<DoctorVisitsSection> createState() => DoctorVisitsSectionState();
}

class DoctorVisitsSectionState extends State<DoctorVisitsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DoctorVisit> _upcomingVisits = [];
  List<DoctorVisit> _pastVisits = [];
  bool _isLoading = true;

  void saveVisit(DoctorVisit visit) => _saveVisit(visit);
  void loadData() => _loadData();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _formatJalaliDateTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final j = Jalali.fromDateTime(dt);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return _toPersianDigits('${j.year}/${j.month}/${j.day} ساعت $hour:$minute');
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

      // Sort past visits descending (most recent first)
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

      // Handle alarm scheduling — registered in pending_reminders so it survives
      // device reboots (BootReceiver reads from active_reminders_snapshot which
      // is built by SnapshotSyncService from pending_reminders).
      final alarmId = 'visit_${visit.id}';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (visit.status == 'UPCOMING') {
        final reminderTime = visit.visitDateTime - (visit.reminderBefore * 60 * 1000);
        if (reminderTime > nowMs) {
          // Upsert into pending_reminders so the snapshot + zone check can work.
          // routineId is NULL intentionally (doctor visits are not in routines table).
          // SQLite allows multiple NULLs in a UNIQUE index so no conflict occurs.
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
          // Sync snapshot so BootReceiver can restore this alarm after reboot
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
      // Remove from pending_reminders so snapshot stays clean
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
        child: RitmoGlassSurface(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(12),
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
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    RitmoHaptics.tap();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return RitmoGlassSegmentedControl<int>(
                selectedIndex: _tabController.index,
                accentColor: colors.primary,
                onTabChanged: (index) {
                  setState(() {
                    _tabController.animateTo(index);
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
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 480,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVisitsList(_upcomingVisits, isPast: false),
                      _buildVisitsList(_pastVisits, isPast: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsList(List<DoctorVisit> visits, {required bool isPast}) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    if (visits.isEmpty) {
      return Center(
        child: Text(
          isPast ? l10n.doctorVisitsNoPast : l10n.doctorVisitsNoUpcoming,
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: visits.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final visit = visits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RitmoCard.neumorphic(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RitmoCardHeader(
                  title: visit.doctorName,
                  subtitle: (visit.specialty != null && visit.specialty!.isNotEmpty) ? visit.specialty! : null,
                  icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                  iconColor: colors.primary,
                  trailing: _buildVisitTypeBadge(visit.visitType),
                ),
                const RitmoCardDivider(),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _formatJalaliDateTime(visit.visitDateTime),
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    ),
                  ],
                ),
                if (visit.clinicName != null && visit.clinicName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.business, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        visit.clinicName!,
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
                if (visit.clinicAddress != null && visit.clinicAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openMap(visit.clinicAddress),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            visit.clinicAddress!,
                            style: TextStyle(
                              fontSize: 13,
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
                if (visit.clinicPhone != null && visit.clinicPhone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _callPhone(visit.clinicPhone),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: colors.success),
                        const SizedBox(width: 6),
                        Text(
                          _toPersianDigits(visit.clinicPhone!),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'علت مراجعه: ${visit.reason}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
                if (visit.doctorNotes != null && visit.doctorNotes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'توصیه پزشک: ${visit.doctorNotes}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
                if (visit.attachmentPath != null && visit.attachmentPath!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showAttachmentViewer(visit.attachmentPath!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'مشاهده نسخه / مدرک ثبت شده',
                            style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 18, color: colors.primary),
                      onPressed: () => _openAddEditPage(visit: visit),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: colors.medicalRed),
                      onPressed: () => _confirmDelete(visit.id),
                    ),
                    if (!isPast) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateVisitStatus(visit, 'COMPLETED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('انجام شد', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
}
