import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/legacy_database_recovery.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/account_reset_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';

class DangerZone extends StatelessWidget {
  const DangerZone({
    super.key,
    required this.onFactoryReset,
  });

  final VoidCallback onFactoryReset;

  static String _normalizePersian(String s) {
    return s
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('\u200c', '')
        .replaceAll(' ', '')
        .trim()
        .toLowerCase();
  }

  Future<void> _showResetDialog(BuildContext context) async {
    String? backupPath;

    try {
      final db = await DatabaseHelper.instance.database;
      backupPath = await LegacyDatabaseRecovery.createEmergencyBackup(db.path);
    } catch (e, st) {
      RitmoLog.error('Settings', 'Emergency backup error', e, st);
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FactoryResetDialog(
        backupPath: backupPath,
        onConfirmed: () async {
          Navigator.pop(ctx);
          await AccountResetService.wipeUserData();
          if (!context.mounted) return;
          RitmoToast.show(context, 'کلیه داده‌ها با موفقیت پاک شدند.');
          onFactoryReset();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.medicalRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.medicalRed.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 18,
                  color: colors.medicalRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'منطقهٔ خطر',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.medicalRed,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.medicalRed.withValues(alpha: 0.15),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showResetDialog(context),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بازنشانی کارخانه‌ای — پاک کردن همهٔ داده‌ها',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.medicalRed,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'پاک‌سازی کامل دیتابیس، تنظیمات و آغاز مجدد از مرحله خوش‌آمدگویی',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.trash_fill,
                      color: colors.medicalRed,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryResetDialog extends StatefulWidget {
  const _FactoryResetDialog({
    required this.backupPath,
    required this.onConfirmed,
  });

  final String? backupPath;
  final Future<void> Function() onConfirmed;

  @override
  State<_FactoryResetDialog> createState() => _FactoryResetDialogState();
}

class _FactoryResetDialogState extends State<_FactoryResetDialog> {
  late final TextEditingController _textController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isConfirmed = DangerZone._normalizePersian(_textController.text) ==
        DangerZone._normalizePersian('پاک کن');

    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: colors.medicalRed, size: 20),
          const SizedBox(width: 8),
          Text(
            'بازنشانی کارخانه‌ای داده‌ها',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.medicalRed,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'با این عملیات کلیه اطلاعات روتین‌ها، یادآوری‌ها، اهداف، آمارها و تنظیمات ریتمو به طور کامل از روی دستگاه پاک خواهد شد.',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.backupPath != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'یک فایل پشتیبان اضطراری در مسیر زیر ایجاد شد:\n${widget.backupPath}',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textTertiary,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'جهت تأیید، عبارت «پاک کن» را در کادر زیر وارد کنید:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.medicalRed,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _textController,
            textAlign: TextAlign.center,
            placeholder: 'پاک کن',
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConfirmed ? colors.medicalRed : colors.border,
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: (isConfirmed && !_isLoading)
              ? () async {
                  setState(() => _isLoading = true);
                  await widget.onConfirmed();
                }
              : null,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(
                  'حذف کامل داده‌ها',
                  style: TextStyle(
                    color: isConfirmed ? colors.medicalRed : colors.textTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
