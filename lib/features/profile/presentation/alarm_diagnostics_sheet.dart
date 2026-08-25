import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class AlarmDiagnosticsSheet extends StatefulWidget {
  const AlarmDiagnosticsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AlarmDiagnosticsSheet(),
    );
  }

  @override
  State<AlarmDiagnosticsSheet> createState() => _AlarmDiagnosticsSheetState();
}

class _AlarmDiagnosticsSheetState extends State<AlarmDiagnosticsSheet> {
  bool _isLoading = true;
  bool _hasExactAlarmPermission = false;
  int _pendingCount = 0;
  int _nativeFailureCount = 0;
  int _missedCount = 0;
  List<Map<String, dynamic>> _discrepancies = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    final hasPerm = await sl<AlarmPlatform>().checkExactAlarmPermission();
    final db = await DatabaseHelper.instance.database;

    final pending = await db.query(
      'pending_reminders',
      where: "state = 'unknown' OR state = 'delayed'",
    );

    final missed = await db.query(
      'pending_reminders',
      where: "state = 'missed'",
    );

    final settings = await db.query(
      'app_settings',
      where: "key = 'alarm_native_failure_count'",
    );
    final failures = settings.isNotEmpty ? (int.tryParse(settings.first['value'] as String) ?? 0) : 0;

    final unScheduledList = await db.query(
      'pending_reminders',
      where: "(state = 'unknown' OR state = 'delayed') AND (nativeScheduled IS NULL OR nativeScheduled = 0)",
    );

    if (mounted) {
      setState(() {
        _hasExactAlarmPermission = hasPerm;
        _pendingCount = pending.length;
        _missedCount = missed.length;
        _nativeFailureCount = failures;
        _discrepancies = unScheduledList;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerTestAlarm() async {
    await RitmoExecutionKernel.instance.execute(const TestAlarmCommand(secondsFromNow: 5));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('آلارم تست تا ۵ ثانیه دیگر فعال می‌شود (گوشی را قفل کنید)'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _repairSyncAlarms() async {
    await AlarmSchedulerService.scheduleNextAlarms();
    await _runDiagnostics();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('همگام‌سازی و بازنویسی آلارم‌ها با موفقیت انجام شد'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عیب‌یابی و سلامت آلارم‌ها',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: colors.primary))
          else ...[
            _buildStatusCard(
              title: 'مجوز آلارم دقیق (Exact Alarm)',
              status: _hasExactAlarmPermission ? 'فعال' : 'غیرفعال (نیازمند مجوز)',
              isOk: _hasExactAlarmPermission,
              onTap: _hasExactAlarmPermission
                  ? null
                  : () => sl<AlarmPlatform>().requestExactAlarmPermission(),
            ),
            const SizedBox(height: 10),
            _buildStatusCard(
              title: 'یادآورهای در انتظار (Pending)',
              status: '$_pendingCount عدد',
              isOk: true,
            ),
            const SizedBox(height: 10),
            _buildStatusCard(
              title: 'یادآورهای از دست رفته (Missed)',
              status: '$_missedCount عدد',
              isOk: _missedCount == 0,
            ),
            const SizedBox(height: 10),
            _buildStatusCard(
              title: 'خطاهای ثبت نیتیو (Native Failures)',
              status: '$_nativeFailureCount خطا',
              isOk: _nativeFailureCount == 0,
            ),
            const SizedBox(height: 10),
            _buildStatusCard(
              title: 'ناهمخوانی ثبت نیتیو',
              status: _discrepancies.isEmpty ? 'هیچ' : '${_discrepancies.length} مورد ثبت نشده',
              isOk: _discrepancies.isEmpty,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _triggerTestAlarm,
              icon: const Icon(Icons.alarm_on),
              label: const Text('تست آلارم ۵ ثانیه‌ای (صفحه قفل)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _repairSyncAlarms,
              icon: const Icon(Icons.build),
              label: const Text('بازسازی و همگام‌سازی مجدد آلارم‌ها'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: colors.border),
                foregroundColor: colors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: content,
        ),
      ),
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required bool isOk,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOk ? Colors.green.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOk ? Colors.green.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green.shade700 : Colors.amber.shade800,
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}
