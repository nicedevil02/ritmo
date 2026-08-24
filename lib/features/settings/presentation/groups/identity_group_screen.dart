import 'dart:ui';
import 'package:flutter/cupertino.dart';
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
import 'package:ritmo/features/settings/presentation/widgets/identity_app_mode_cards.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_hero_card.dart';

/// صفحهٔ حساب و هویت با زبان طراحی فوق‌مدرن iOS 26 و افکت‌های کریستالی
class IdentityGroupScreen extends StatefulWidget {
  final String? highlightKey;

  const IdentityGroupScreen({
    super.key,
    this.highlightKey,
  });

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
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: colors.textPrimary,
          ),
        ),
        message: Text(
          'یک تصویر برای نمایهٔ کاربری خود انتخاب کنید',
          style: TextStyle(
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
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'نامی که در پیام‌ها و تبریک‌ها نمایش داده می‌شود',
                                    style: TextStyle(
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
                              fontSize: 14,
                              color: colors.textTertiary,
                            ),
                            style: TextStyle(
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
                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                  if (mounted) {
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'برای تنظیم هوشمند ماژول‌های مرتبط (مانند چرخه سلامت)',
                    style: TextStyle(
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
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? optColor : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['subtitle'] as String,
                                      style: TextStyle(
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
                            color: colors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'انتخاب سن',
                        style: TextStyle(
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
      padding: EdgeInsets.zero,
      appBar: const RitmoModuleAppBar(
        title: 'حساب و هویت',
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Hero Identity & Avatar Card ───────────────────────────
            IdentityHeroCard(
              userName: _userName,
              avatarPath: _avatarPath,
              genderLabel: genderLabel,
              age: _age,
              appMode: _appMode,
              onPickAvatar: _pickAvatar,
              onEditName: _editNameModal,
            ),

            const SizedBox(height: 24),

            // ── 2. Identity Information Grouped Card ──────────────────────
            _buildSectionHeader('اطلاعات هویتی و فردی', CupertinoIcons.person_badge_plus_fill, colors),
            const SizedBox(height: 10),
            _buildIdentityGroupCard(context, colors, isDark, genderLabel),

            const SizedBox(height: 28),

            // ── 3. App Experience Mode Selector ──────────────────────────
            _buildSectionHeader('حالت اپلیکیشن', CupertinoIcons.slider_horizontal_3, colors),
            const SizedBox(height: 10),
            IdentityAppModeCards(
              appMode: _appMode,
              onModeChanged: _switchAppMode,
            ),

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
