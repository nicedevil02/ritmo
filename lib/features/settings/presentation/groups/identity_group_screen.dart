import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/module_management_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';

/// صفحهٔ حساب و هویت با زبان طراحی فوق‌مدرن iOS 26 و افکت‌های کریستالی
class IdentityGroupScreen extends StatefulWidget {
  const IdentityGroupScreen({super.key});

  @override
  State<IdentityGroupScreen> createState() => _IdentityGroupScreenState();
}

class _IdentityGroupScreenState extends State<IdentityGroupScreen> {
  late final TextEditingController _nameController;
  String _userName = '';
  String _avatarPath = '';
  String _gender = 'UNSET';
  int _age = 25;
  String _appMode = 'full';

  @override
  void initState() {
    super.initState();
    _userName = SettingsService.instance.get<String>('user_name');
    _nameController = TextEditingController(text: _userName);
    _avatarPath = SettingsService.instance.get<String>('user_avatar_path');
    _gender = SettingsService.instance.get<String>('user_gender');
    _age = SettingsService.instance.get<int>('user_age');
    _appMode = SettingsService.instance.get<String>('app_mode');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isAvatarFileValid(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('data:')) {
      return true;
    }
    if (!kIsWeb) {
      try {
        return File(path).existsSync();
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<void> _pickAvatar() async {
    RitmoHapticsPolicy.selection();
    final colors = context.colors;

    await showCupertinoModalPopup<void>(
      context: context,
      barrierColor: colors.overlay,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'ویرایش عکس پروفایل',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: colors.textPrimary,
          ),
        ),
        message: Text(
          'یک تصویر برای نمایهٔ کاربری خود انتخاب کنید',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (picked != null) {
                setState(() => _avatarPath = picked.path);
                await SettingsService.instance.set('user_avatar_path', picked.path);
                RitmoHapticsPolicy.success();
                if (mounted) {
                  RitmoToast.show(context, 'عکس پروفایل با موفقیت به‌روزرسانی شد ✨');
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'انتخاب از گالری',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              if (picked != null) {
                setState(() => _avatarPath = picked.path);
                await SettingsService.instance.set('user_avatar_path', picked.path);
                RitmoHapticsPolicy.success();
                if (mounted) {
                  RitmoToast.show(context, 'عکس پروفایل با موفقیت ثبت شد 📸');
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'ثبت عکس با دوربین',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_avatarPath.isNotEmpty)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _avatarPath = '');
                await SettingsService.instance.set('user_avatar_path', '');
                RitmoHapticsPolicy.warning();
                if (mounted) {
                  RitmoToast.show(context, 'عکس پروفایل حذف شد.');
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.trash, size: 20, color: colors.medicalRed),
                  const SizedBox(width: 10),
                  Text(
                    'حذف عکس پروفایل',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: colors.medicalRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'انصراف',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editNameModal() async {
    RitmoHapticsPolicy.tap();
    final colors = context.colors;
    final isDark = context.isDark;
    _nameController.text = _userName;
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.person_crop_circle_fill,
                                color: colors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ویرایش نام کاربری',
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'نامی که در پیام‌ها و تبریک‌ها نمایش داده می‌شود',
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: localError != null
                                  ? colors.medicalRed
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.08)),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _nameController,
                            autofocus: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            placeholder: 'نام و نام خانوادگی خود را وارد کنید',
                            placeholderStyle: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 14,
                              color: colors.textTertiary,
                            ),
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 15,
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: null,
                            onChanged: (_) {
                              if (localError != null) {
                                setModalState(() => localError = null);
                              }
                            },
                          ),
                        ),
                        if (localError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            localError!,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              color: colors.medicalRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                onPressed: () => Navigator.pop(bottomSheetContext),
                                child: Text(
                                  'انصراف',
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: () async {
                                  final text = _nameController.text.trim();
                                  if (text.isEmpty) {
                                    setModalState(() {
                                      localError = 'نام نمی‌تواند خالی باشد.';
                                    });
                                    RitmoHapticsPolicy.error();
                                    return;
                                  }

                                  setState(() => _userName = text);
                                  await SettingsService.instance.set('user_name', text);
                                  RitmoHapticsPolicy.success();
                                  if (mounted) {
                                    Navigator.pop(bottomSheetContext);
                                    RitmoToast.show(
                                      context,
                                      'نام با موفقیت ذخیره شد ✨',
                                    );
                                  }
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'ذخیره تغییرات',
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeGender(String val) async {
    final upperVal = val.toUpperCase();
    RitmoHapticsPolicy.selection();
    setState(() => _gender = upperVal);
    await SettingsService.instance.set('user_gender', upperVal);
    await SettingsService.instance.set('identity_gender_asked', true);

    if (upperVal == 'FEMALE') {
      await ModuleManagementService.instance.setModuleEnabled('module_cycle_enabled', true);
      await AlarmSchedulerService.scheduleNextAlarms();
    } else {
      await ModuleManagementService.instance.setModuleEnabled('module_cycle_enabled', false);
      await AlarmSchedulerService.scheduleNextAlarms();
    }

    if (mounted) {
      RitmoToast.show(context, 'جنسیت با موفقیت به‌روز شد.');
    }
  }

  Future<void> _pickGenderModal() async {
    RitmoHapticsPolicy.tap();
    final colors = context.colors;
    final isDark = context.isDark;

    final options = [
      {
        'key': 'MALE',
        'title': 'آقا (مرد)',
        'subtitle': 'تنظیمات و ماژول‌های متناسب با آقایان',
        'icon': CupertinoIcons.person_crop_circle_fill,
        'color': const Color(0xFF3B82F6),
      },
      {
        'key': 'FEMALE',
        'title': 'خانم (زن)',
        'subtitle': 'فعال‌سازی هوشمند چرخه سلامت بانوان',
        'icon': CupertinoIcons.sparkles,
        'color': const Color(0xFFEC4899),
      },
      {
        'key': 'OTHER',
        'title': 'ترجیح می‌دهم نگویم',
        'subtitle': 'استفاده عمومی بدون تفکیک جنسیتی',
        'icon': CupertinoIcons.circle_grid_hex_fill,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'انتخاب جنسیت',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'برای تنظیم هوشمند ماژول‌های مرتبط (مانند چرخه سلامت)',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...options.map((opt) {
                    final isSelected = _gender == opt['key'] ||
                        (_gender == 'male' && opt['key'] == 'MALE') ||
                        (_gender == 'female' && opt['key'] == 'FEMALE') ||
                        (_gender == 'other' && opt['key'] == 'OTHER');

                    final optColor = opt['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _changeGender(opt['key'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? optColor.withValues(alpha: 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? optColor.withValues(alpha: 0.6)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: optColor.withValues(alpha: isSelected ? 0.2 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  opt['icon'] as IconData,
                                  color: optColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['title'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? optColor : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['subtitle'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: optColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.checkmark,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAge() async {
    RitmoHapticsPolicy.tap();
    final colors = context.colors;
    final isDark = context.isDark;
    int tempAge = _age;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 330,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'انصراف',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            color: colors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'انتخاب سن',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          setState(() => _age = tempAge);
                          await SettingsService.instance.set('user_age', tempAge);
                          await SettingsService.instance.set('identity_age_asked', true);
                          RitmoHapticsPolicy.success();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            RitmoToast.show(context, 'سن با موفقیت ثبت شد.');
                          }
                        },
                        child: Text(
                          'تأیید',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            color: colors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 42,
                      scrollController: FixedExtentScrollController(
                        initialItem: (_age >= 10 && _age <= 120) ? _age - 10 : 15,
                      ),
                      onSelectedItemChanged: (index) {
                        tempAge = 10 + index;
                        RitmoHapticsPolicy.selection();
                      },
                      children: List.generate(
                        111,
                        (i) => Center(
                          child: Text(
                            '${toPersianDigits(10 + i)} سال',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchAppMode(String mode) async {
    RitmoHapticsPolicy.selection();
    setState(() => _appMode = mode);
    await SettingsService.instance.set('app_mode', mode);
    await AppModeService.instance.set(mode == 'simple' ? AppMode.simple : AppMode.full);
    RitmoHapticsPolicy.success();
    if (mounted) {
      RitmoToast.show(
        context,
        mode == 'full'
            ? 'نسخهٔ کامل فعال شد ✨'
            : 'نسخهٔ ساده و مینیمال فعال شد 🌿',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    final genderLabel = switch (_gender.toUpperCase()) {
      'MALE' => 'آقا (مرد)',
      'FEMALE' => 'خانم (زن)',
      'OTHER' || 'PREFER_NOT_TO_SAY' => 'ترجیح می‌دهم نگویم',
      _ => 'مشخص نشده',
    };


    return RitmoPageScaffold(
      appBar: const RitmoModuleAppBar(
        title: 'حساب و هویت',
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Hero Identity & Avatar Card ───────────────────────────
            _buildHeroIdentityCard(context, colors, isDark, genderLabel),

            const SizedBox(height: 24),

            // ── 2. Identity Information Grouped Card ──────────────────────
            _buildSectionHeader('اطلاعات هویتی و فردی', CupertinoIcons.person_badge_plus_fill, colors),
            const SizedBox(height: 10),
            _buildIdentityGroupCard(context, colors, isDark, genderLabel),

            const SizedBox(height: 28),

            // ── 3. App Experience Mode Selector ──────────────────────────
            _buildSectionHeader('حالت اپلیکیشن', CupertinoIcons.slider_horizontal_3, colors),
            const SizedBox(height: 10),
            _buildAppModeExperienceCards(context, colors, isDark),

            const SizedBox(height: 28),

            // ── 4. Privacy & Security Assurance Footer ────────────────────
            _buildPrivacyReassuranceBadge(colors, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIdentityCard(
    BuildContext context,
    dynamic colors,
    bool isDark,
    String genderLabel,
  ) {
    final displayName = _userName.trim().isNotEmpty ? _userName.trim() : 'کاربر گرامی';
    final hasValidAvatar = _isAvatarFileValid(_avatarPath);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colors.surfaceElevated,
                  colors.surface,
                ]
              : [
                  Colors.white,
                  colors.surface,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : colors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Avatar with Glowing Ring and Camera Floating Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer subtle gradient glow ring
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary,
                            const Color(0xFF38BDF8),
                            const Color(0xFFA855F7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: hasValidAvatar
                              ? (_avatarPath.startsWith('http') || _avatarPath.startsWith('blob:')
                                  ? Image.network(
                                      _avatarPath,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_avatarPath),
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ))
                              : Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colors.primary.withValues(alpha: 0.25),
                                        colors.primary.withValues(alpha: 0.08),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.person_fill,
                                    size: 46,
                                    color: colors.primary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Floating Glass Camera Button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Name with Quick Edit Button
                GestureDetector(
                  onTap: _editNameModal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 14,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Quick Identity Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildHeroBadge(
                      icon: CupertinoIcons.sparkles,
                      label: _appMode == 'full' ? 'نسخهٔ کامل' : 'نسخهٔ ساده',
                      color: _appMode == 'full' ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    _buildHeroBadge(
                      icon: CupertinoIcons.person_fill,
                      label: genderLabel,
                      color: colors.primary,
                      isDark: isDark,
                    ),
                    _buildHeroBadge(
                      icon: CupertinoIcons.calendar,
                      label: '${toPersianDigits(_age)} سال',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityGroupCard(
    BuildContext context,
    dynamic colors,
    bool isDark,
    String genderLabel,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Name
          _buildFrostedTile(
            icon: CupertinoIcons.person_crop_circle_fill,
            iconColor: const Color(0xFF0EA5E9),
            title: 'نام و نام خانوادگی',
            value: _userName.trim().isNotEmpty ? _userName.trim() : 'تنظیم نشده',
            onTap: _editNameModal,
            isFirst: true,
            isDark: isDark,
            colors: colors,
          ),
          _buildDivider(colors, isDark),

          // Row 2: Avatar Photo
          _buildFrostedTile(
            icon: CupertinoIcons.camera_fill,
            iconColor: const Color(0xFF8B5CF6),
            title: 'تصویر پروفایل',
            value: _avatarPath.isNotEmpty ? 'عکس اختصاصی' : 'پیش‌فرض (بدون تصویر)',
            onTap: _pickAvatar,
            isDark: isDark,
            colors: colors,
          ),
          _buildDivider(colors, isDark),

          // Row 3: Gender
          _buildFrostedTile(
            icon: CupertinoIcons.person_2_fill,
            iconColor: const Color(0xFFEC4899),
            title: 'جنسیت',
            value: genderLabel,
            onTap: _pickGenderModal,
            isDark: isDark,
            colors: colors,
          ),
          _buildDivider(colors, isDark),

          // Row 4: Age
          _buildFrostedTile(
            icon: CupertinoIcons.hourglass,
            iconColor: const Color(0xFFF59E0B),
            title: 'سن کاربر',
            value: '${toPersianDigits(_age)} سال',
            onTap: _pickAge,
            isLast: true,
            isDark: isDark,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    required dynamic colors,
    required bool isDark,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RitmoHapticsPolicy.tap();
          onTap();
        },
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      iconColor.withValues(alpha: isDark ? 0.10 : 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: iconColor.withValues(alpha: isDark ? 0.35 : 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),

              // Value badge & Chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_back,
                    size: 15,
                    color: colors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(dynamic colors, bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildAppModeExperienceCards(
    BuildContext context,
    dynamic colors,
    bool isDark,
  ) {
    final isFullSelected = _appMode == 'full';
    final isSimpleSelected = _appMode == 'simple';

    return Column(
      children: [
        // Card 1: Full Experience
        _buildModeSelectCard(
          isSelected: isFullSelected,
          title: 'نسخهٔ جامع و کامل',
          badge: 'پیشنهادی ریتمو',
          description:
              'دسترسی کامل به تمام ماژول‌ها، تحلیل‌های هوشمند، برنامه‌ریزی پیشرفته، روتین‌ها و ابزارهای هوش مصنوعی.',
          icon: CupertinoIcons.sparkles,
          themeColor: const Color(0xFF10B981),
          tags: ['تمامی ماژول‌ها', 'هوش مصنوعی', 'تحلیل پیشرفته'],
          onTap: () => _switchAppMode('full'),
          isDark: isDark,
          colors: colors,
        ),

        const SizedBox(height: 12),

        // Card 2: Simple Experience
        _buildModeSelectCard(
          isSelected: isSimpleSelected,
          title: 'نسخهٔ ساده و مینیمال',
          badge: 'نهایت تمرکز',
          description:
              'محیطی خلوت و بدون دغدغه که تنها روتین‌ها و تایمرهای ضروری را برای آرامش ذهنی نمایش می‌دهد.',
          icon: CupertinoIcons.bolt_horizontal_circle_fill,
          themeColor: const Color(0xFF3B82F6),
          tags: ['فقط روتین‌ها', 'تایمرها', 'تمرکز خالص'],
          onTap: () => _switchAppMode('simple'),
          isDark: isDark,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildModeSelectCard({
    required bool isSelected,
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required Color themeColor,
    required List<String> tags,
    required VoidCallback onTap,
    required bool isDark,
    required dynamic colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? themeColor.withValues(alpha: isDark ? 0.7 : 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: themeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            else if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: isSelected ? 0.22 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: themeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? themeColor : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Selection Radio Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? themeColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? themeColor
                          : colors.textSecondary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          CupertinoIcons.checkmark,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '• $t',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyReassuranceBadge(dynamic colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colors.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.lock_shield_fill,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تمام اطلاعات هویتی و تنظیمات شما به‌صورت کاملاً محلی، آفلاین و امن روی دستگاه ذخیره می‌شود.',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
