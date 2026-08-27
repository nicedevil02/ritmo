import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/profile_avatar_cropper_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_app_mode_toggle.dart';
import 'package:sqflite/sqflite.dart';

/// هدر هویتی پرمیوم iOS 26 — بالای صفحه تنظیمات
/// تعاملی‌سازی کامل: کلیک روی عکس (تغییر آواتار)، کلیک روی حالت برنامه (سوئیچ ساده/کامل)،
/// کلیک روی آمارها (میان‌برهای هوشمند و پیام‌های وضعیت)
class IdentityHeader extends StatefulWidget {
  const IdentityHeader({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<IdentityHeader> createState() => _IdentityHeaderState();
}

class _IdentityHeaderState extends State<IdentityHeader>
    with SingleTickerProviderStateMixin {
  String _userName = 'کاربر ریتمو';
  String _avatarPath = '';
  int _daysWithRitmo = 1;
  int _activeRoutinesCount = 0;
  int _completedTodayCount = 0;
  bool _isSimpleMode = false;
  bool _isLoading = true;

  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _isSimpleMode = AppModeService.instance.isSimple;
    _loadIdentityData();
    SettingsService.instance.revision.addListener(_onSettingsChanged);
    AppModeService.instance.notifier.addListener(_onAppModeChanged);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.stop();
    _ringController.dispose();
    AppModeService.instance.notifier.removeListener(_onAppModeChanged);
    SettingsService.instance.revision.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onAppModeChanged() {
    if (mounted) {
      setState(() {
        _isSimpleMode = AppModeService.instance.isSimple;
      });
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _isSimpleMode = AppModeService.instance.isSimple;
      });
    }
    _loadIdentityData();
  }

  Future<void> _loadIdentityData() async {
    try {
      final name = SettingsService.instance.get<String>('user_name');
      if (name.isNotEmpty) {
        _userName = name;
      }

      _avatarPath = SettingsService.instance.get<String>('user_avatar_path');
      _isSimpleMode = AppModeService.instance.isSimple;

      final db = await DatabaseHelper.instance.database;
      _daysWithRitmo = 1;

      final activeRoutines = await db.rawQuery(
        'SELECT COUNT(*) FROM routines WHERE isArchived = 0',
      );
      final cnt = Sqflite.firstIntValue(activeRoutines) ?? 0;
      _activeRoutinesCount = cnt;

      // محاسبه فعالیت‌های تکمیل‌شده امروز
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      int completedCount = 0;
      try {
        final completedRoutines = await db.rawQuery(
          'SELECT COUNT(*) FROM routine_completions WHERE completionDate = ?',
          [dateStr],
        );
        completedCount += Sqflite.firstIntValue(completedRoutines) ?? 0;
      } catch (_) {}
      try {
        final completedTasks = await db.rawQuery(
          'SELECT COUNT(*) FROM simple_tasks WHERE isDone = 1 AND dueDate = ?',
          [dateStr],
        );
        completedCount += Sqflite.firstIntValue(completedTasks) ?? 0;
      } catch (_) {}
      try {
        final completedAgenda = await db.rawQuery(
          'SELECT COUNT(*) FROM agenda_items WHERE isCompleted = 1 AND dateStr = ?',
          [dateStr],
        );
        completedCount += Sqflite.firstIntValue(completedAgenda) ?? 0;
      } catch (_) {}
      _completedTodayCount = completedCount;
    } catch (e, st) {
      RitmoLog.error('Settings', 'Error loading identity header', e, st);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// باز کردن شیت تعاملی انتخاب عکس پروفایل
  Future<void> _pickAvatar() async {
    RitmoHapticsPolicy.selection();
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final content = Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ویرایش عکس نمایه',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'یک تصویر جدید برای نمایهٔ خود انتخاب کنید',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Gallery Button
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.photo_on_rectangle, size: 20, color: colors.primary),
                  ),
                  title: Text(
                    'انتخاب از گالری',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final croppedPath = await ProfileAvatarService.pickAndCropAvatar(
                      context,
                      source: ImageSource.gallery,
                    );
                    if (croppedPath != null && mounted) {
                      setState(() => _avatarPath = croppedPath);
                      RitmoHapticsPolicy.success();
                      RitmoToast.show(context, 'عکس پروفایل با موفقیت به‌روزرسانی شد ✨');
                    }
                  },
                ),
              ),

              // Camera Button
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.camera_fill, size: 20, color: colors.primary),
                  ),
                  title: Text(
                    'گرفتن عکس جدید (دوربین)',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final croppedPath = await ProfileAvatarService.pickAndCropAvatar(
                      context,
                      source: ImageSource.camera,
                    );
                    if (croppedPath != null && mounted) {
                      setState(() => _avatarPath = croppedPath);
                      RitmoHapticsPolicy.success();
                      RitmoToast.show(context, 'عکس پروفایل با موفقیت به‌روزرسانی شد 📸');
                    }
                  },
                ),
              ),

              // Delete avatar button if exists
              if (_avatarPath.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: colors.medicalRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.medicalRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.medicalRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.trash, size: 20, color: colors.medicalRed),
                    ),
                    title: Text(
                      'حذف عکس پروفایل',
                      style: TextStyle(
                        color: colors.medicalRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ProfileAvatarService.removeAvatar(context);
                      if (mounted) {
                        setState(() => _avatarPath = '');
                        RitmoHapticsPolicy.warning();
                        RitmoToast.show(context, 'عکس پروفایل حذف شد.');
                      }
                    },
                  ),
                ),
            ],
          ),
        );

        final sheetBody = Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            type: MaterialType.transparency,
            child: content,
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
      },
    );
  }



  String _getMonogram(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ر';
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1);
  }

  bool _isAvatarFileValid(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:') || path.startsWith('data:')) {
      return true;
    }
    if (!kIsWeb) {
      try {
        return File(path).existsSync();
      } catch (e, st) {
        RitmoLog.error('Settings', 'Failed to check avatar file exists in header', e, st);
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return _buildSkeleton(colors);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Row(
                children: [
                  // ─── آواتار با قابلیت کلیک مستقیم برای تغییر عکس ───
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: _buildAvatarWithBadge(colors),
                  ),
                    const SizedBox(width: 16),

                    // ─── بخش اطلاعات نام + زیرعنوان ───
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'ویرایش پروفایل و تنظیمات',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textTertiary,
                                  ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.chevron_back,
                                size: 12,
                                color: colors.textTertiary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ─── شورون (دکمه اکشن) ───
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 16,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

                // ─── نوار آمارهای سه‌گانه زنده ───
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        icon: CupertinoIcons.calendar_today,
                        label: '${toPersianDigits(_daysWithRitmo)} روز',
                        sublabel: 'همراهی',
                        color: colors.accent,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatChip(
                        icon: CupertinoIcons.bolt_fill,
                        label: '${toPersianDigits(_activeRoutinesCount)} کار',
                        sublabel: 'فعال',
                        color: colors.primary,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatChip(
                        icon: CupertinoIcons.checkmark_seal_fill,
                        label: '${toPersianDigits(_completedTodayCount)} ثبت',
                        sublabel: 'امروز',
                        color: const Color(0xFF00C9FF),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── سگمنت کنترل دو گزینه‌ای انتخاب حالت اپلیکیشن ───
                IdentityAppModeToggle(
                  isSimpleMode: _isSimpleMode,
                  onModeChanged: (val) => setState(() => _isSimpleMode = val),
                ),
              ],
            ),
        );
      }

  /// ساخت آواتار با حلقه هولوگرام و نشان دوربین
  Widget _buildAvatarWithBadge(RitmoColors colors) {
    const double outerSize = 68;
    const double ringWidth = 3.0;
    const double gapWidth = 2.0;
    const double innerSize = outerSize - (ringWidth + gapWidth) * 2;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _ringController,
          builder: (context, child) {
            return Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: GradientRotation(_ringController.value * math.pi * 2),
                  colors: [
                    colors.brandGradient.first,
                    colors.brandGradient.last,
                    colors.accent,
                    colors.brandGradient.first,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Center(
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
              ),
              child: _isAvatarFileValid(_avatarPath)
                  ? ClipOval(
                      child: _avatarPath.startsWith('http') || _avatarPath.startsWith('blob:')
                          ? Image.network(
                              _avatarPath,
                              width: innerSize,
                              height: innerSize,
                              cacheWidth: 200,
                              cacheHeight: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_avatarPath),
                              width: innerSize,
                              height: innerSize,
                              cacheWidth: 200,
                              cacheHeight: 200,
                              fit: BoxFit.cover,
                            ),
                    )
                  : Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: colors.brandGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          _getMonogram(_userName),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        // نشان دکمه دوربین کوچک روی لبه آواتار
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.camera_fill,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// بج آماری سه‌گانه شیشه‌ای با زیرمتن
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required RitmoColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textTertiary,
              ),
          ),
        ],
      ),
    );
  }

  /// حالت بارگذاری (اسکلتون)
  Widget _buildSkeleton(RitmoColors colors) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: const Center(
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}
