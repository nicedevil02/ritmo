import 'package:ritmo/core/settings/settings_service.dart';

enum SettingsIssueSeverity {
  warning,
  error,
}

class SettingsIssue {
  const SettingsIssue({
    required this.id,
    required this.titleFa,
    required this.descriptionFa,
    required this.severity,
    required this.fixActionFa,
    required this.autoFix,
  });

  final String id;
  final String titleFa;
  final String descriptionFa;
  final SettingsIssueSeverity severity;
  final String fixActionFa;
  final Future<void> Function() autoFix;
}

class SettingsHealthService {
  SettingsHealthService._();
  static final SettingsHealthService instance = SettingsHealthService._();

  List<SettingsIssue> inspect() {
    final issues = <SettingsIssue>[];
    final svc = SettingsService.instance;

    // 1. Biometric lock enabled without master app lock
    final appLock = svc.get<bool>('app_lock_enabled');
    final biometric = svc.get<bool>('app_biometric_enabled');
    if (biometric && !appLock) {
      issues.add(
        SettingsIssue(
          id: 'biometric_without_app_lock',
          titleFa: 'بیومتریک بدون فعال بودن قفل برنامه',
          descriptionFa: 'حسگر بیومتریک روشن است اما قفل کلی برنامه خاموش است و اثری ندارد.',
          severity: SettingsIssueSeverity.warning,
          fixActionFa: 'فعال‌سازی قفل برنامه',
          autoFix: () async {
            await svc.set('app_lock_enabled', true);
          },
        ),
      );
    }

    // 2. Quiet hours enabled with equal start and end time
    final quietEnabled = svc.get<bool>('notif_quiet_enabled');
    final quietStart = svc.get<String>('notif_quiet_start');
    final quietEnd = svc.get<String>('notif_quiet_end');
    if (quietEnabled && quietStart.isNotEmpty && quietStart == quietEnd) {
      issues.add(
        SettingsIssue(
          id: 'quiet_hours_equal_start_end',
          titleFa: 'بازهٔ نامعتبر ساعات سکوت',
          descriptionFa: 'زمان شروع و پایان ساعات سکوت یکسان است و اثری در آرامش اعلان‌ها ندارد.',
          severity: SettingsIssueSeverity.warning,
          fixActionFa: 'تنظیم پیش‌فرض (۰۰:۰۰ تا ۰۷:۰۰)',
          autoFix: () async {
            await svc.set('notif_quiet_start', '00:00');
            await svc.set('notif_quiet_end', '07:00');
          },
        ),
      );
    }

    // 3. Auto backup frequency <= 0
    final autoBackup = svc.get<bool>('auto_backup_enabled');
    final backupFreq = svc.get<int>('backup_frequency_days');
    if (autoBackup && backupFreq <= 0) {
      issues.add(
        SettingsIssue(
          id: 'invalid_backup_frequency',
          titleFa: 'دورهٔ نامعتبر پشتیبان‌گیری',
          descriptionFa: 'پشتیبان‌گیری خودکار روشن است ولی دورهٔ آن صفر یا منفی تعیین شده است.',
          severity: SettingsIssueSeverity.error,
          fixActionFa: 'تنظیم روی ۷ روز',
          autoFix: () async {
            await svc.set('backup_frequency_days', 7);
          },
        ),
      );
    }

    return issues;
  }

  Future<void> fixAll() async {
    final issues = inspect();
    for (final issue in issues) {
      await issue.autoFix();
    }
  }
}
