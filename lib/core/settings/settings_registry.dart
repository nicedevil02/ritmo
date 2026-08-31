import 'package:flutter/material.dart';

enum SettingScope { db, prefs, secure }

enum SettingType { boolean, integer, text, enumeration, time }

enum SettingsGroup {
  identity,
  modules,
  notifications,
  appearance,
  assistant,
  dataBackup,
  security,
  calendar;

  String get labelFa {
    switch (this) {
      case SettingsGroup.identity:
        return 'حساب و هویت';
      case SettingsGroup.modules:
        return 'مدیریت ماژول‌ها و بخش‌ها';
      case SettingsGroup.notifications:
        return 'اعلان‌ها و یادآوری‌ها';
      case SettingsGroup.appearance:
        return 'ظاهر و زبان';
      case SettingsGroup.assistant:
        return 'دستیار و هوش مصنوعی';
      case SettingsGroup.dataBackup:
        return 'داده و پشتیبان';
      case SettingsGroup.security:
        return 'امنیت و حریم خصوصی';
      case SettingsGroup.calendar:
        return 'تقویم و برنامه‌ریزی';
    }
  }

  String get subtitleFa {
    switch (this) {
      case SettingsGroup.identity:
        return 'نام، سن، جنسیت و حالت اپلیکیشن (ساده / کامل)';
      case SettingsGroup.modules:
        return 'فعال‌سازی، پیکربندی و بازنشانی بخش‌های مختلف';
      case SettingsGroup.notifications:
        return 'کلید اصلی، ساعات سکوت، تجمیع و تعویق آلارم‌ها';
      case SettingsGroup.appearance:
        return 'حالت روشنایی، پالت رنگ، سیاه خالص OLED و زبان';
      case SettingsGroup.assistant:
        return 'هوش مصنوعی، حافظه شناختی و تنظیمات رفتار روان‌شناختی';
      case SettingsGroup.dataBackup:
        return 'پشتیبان‌گیری محلی، گزارش خطاها، پاک‌سازی و بازنشانی';
      case SettingsGroup.security:
        return 'قفل ورود، بیومتریک، مهلت قفل و رمز بخش چرخه';
      case SettingsGroup.calendar:
        return 'نمای پیش‌فرض، نمایش مناسبت‌ها، تسک‌ها و خلاصه صبحگاهی';
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsGroup.identity:
        return Icons.person_outline_rounded;
      case SettingsGroup.modules:
        return Icons.grid_view_rounded;
      case SettingsGroup.notifications:
        return Icons.notifications_none_rounded;
      case SettingsGroup.appearance:
        return Icons.palette_outlined;
      case SettingsGroup.assistant:
        return Icons.auto_awesome_outlined;
      case SettingsGroup.dataBackup:
        return Icons.backup_outlined;
      case SettingsGroup.security:
        return Icons.security_rounded;
      case SettingsGroup.calendar:
        return Icons.calendar_month_outlined;
    }
  }

  int get sortOrder {
    switch (this) {
      case SettingsGroup.identity:
        return 1;
      case SettingsGroup.modules:
        return 2;
      case SettingsGroup.notifications:
        return 3;
      case SettingsGroup.appearance:
        return 4;
      case SettingsGroup.assistant:
        return 5;
      case SettingsGroup.dataBackup:
        return 6;
      case SettingsGroup.security:
        return 7;
      case SettingsGroup.calendar:
        return 8;
    }
  }
}

abstract final class AppLockTimeout {
  static const int immediate = 0;
  static const int never = -1;
  static const List<int> presets = [immediate, 60, 300, 900, never];
}

enum SettingVisibility {
  /// در فهرست گروه و جست‌وجو دیده می‌شود.
  normal,

  /// فقط وقتی «نمایش تنظیمات پیشرفته» روشن باشد.
  advanced,

  /// وضعیت داخلی؛ نه در فهرست، نه در جست‌وجو.
  internal,
}

@immutable
class SettingCondition {
  final String key;
  final Object? expectedValue; // اگر null باشد یعنی باید والد true باشد

  const SettingCondition(this.key, [this.expectedValue]);

  bool isSatisfied(Object? actualValue) {
    if (expectedValue == null) {
      return actualValue == true || actualValue == 'true';
    }
    return actualValue == expectedValue ||
        actualValue == expectedValue.toString();
  }
}

@immutable
class SettingDescriptor {
  const SettingDescriptor({
    required this.key,
    required this.type,
    required this.scope,
    required this.defaultValue,
    required this.labelFa,
    required this.group,
    this.descriptionFa,
    this.whyExplanationFa,
    this.min,
    this.max,
    this.allowed,
    this.aiWritable = false,
    this.searchTerms = const [],
    this.visibility = SettingVisibility.normal,
    this.dependsOn,
    this.affectsAgenda = false,
    this.requiresRestart = false,
    this.isResettable = true,
    this.icon,
    this.unitFa,
    this.optionLabelsFa,
    this.searchTermsEn = const [],
  }) : assert(
         type != SettingType.boolean || defaultValue is bool,
         'Boolean setting $key must have bool defaultValue',
       ),
       assert(
         type != SettingType.integer ||
             (defaultValue is int &&
                 (min == null || defaultValue >= min) &&
                 (max == null || defaultValue <= max)),
         'Integer setting $key defaultValue ($defaultValue) must be int within [$min, $max]',
       ),
       assert(
         (type != SettingType.text &&
                 type != SettingType.enumeration &&
                 type != SettingType.time) ||
             defaultValue is String,
         'Text/Enum/Time setting $key must have String defaultValue',
       ),
       assert(
         type != SettingType.enumeration || allowed != null,
         'Enum setting $key must have allowed list',
       ),
       assert(
         min == null || max == null || min <= max,
         'Setting $key min ($min) must be <= max ($max)',
       ),
       assert(
         type != SettingType.time ||
             (defaultValue is String && defaultValue.length == 5),
         'Time setting $key defaultValue ($defaultValue) must match HH:mm pattern',
       );

  final String key;
  final SettingType type;
  final SettingScope scope;
  final Object defaultValue;
  final String labelFa;
  final SettingsGroup group;
  final String? descriptionFa;
  final String? whyExplanationFa;
  final int? min;
  final int? max;
  final List<String>? allowed;
  final bool aiWritable;
  final List<String> searchTerms;
  final SettingVisibility visibility;
  final SettingCondition? dependsOn;
  final bool affectsAgenda;
  final bool requiresRestart;
  final bool isResettable;
  final IconData? icon;
  final String? unitFa;
  final Map<String, String>? optionLabelsFa;
  final List<String> searchTermsEn;

  bool get isSecret =>
      scope == SettingScope.secure ||
      key.contains('password') ||
      key.contains('api_key') ||
      key.contains('token');

  bool isEnabled(Map<String, dynamic> currentSettings) {
    final c = dependsOn;
    if (c == null) return true;
    final parentVal = currentSettings[c.key];
    return c.isSatisfied(parentVal);
  }

  Object parseValue(Object? raw) {
    if (raw == null) return defaultValue;
    switch (type) {
      case SettingType.boolean:
        if (raw is bool) return raw;
        final s = raw.toString().trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      case SettingType.integer:
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        final parsed = int.tryParse(raw.toString().trim());
        return parsed ?? defaultValue;
      case SettingType.text:
      case SettingType.time:
        return raw.toString();
      case SettingType.enumeration:
        final str = raw.toString();
        if (allowed == null) return str;
        final match = allowed!.firstWhere(
          (a) => a.toUpperCase() == str.toUpperCase(),
          orElse: () => defaultValue as String,
        );
        return match;
    }
  }
}

class SettingsRegistry {
  SettingsRegistry._();

  static const List<SettingDescriptor> all = [
    // ----------------------------------------------------
    // ۱. حساب و هویت (Identity)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'user_name',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: 'بهمن',
      labelFa: 'نام و نام خانوادگی',
      group: SettingsGroup.identity,
      descriptionFa: 'نام نمایش‌داده‌شده در سربرگ و گفتگوهای هوش مصنوعی',
      searchTerms: ['نام', 'اسم', 'پروفایل', 'هویت'],
    ),
    SettingDescriptor(
      key: 'user_gender',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'UNSET',
      labelFa: 'جنسیت',
      group: SettingsGroup.identity,
      allowed: ['UNSET', 'MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'],
      optionLabelsFa: {
        'UNSET': 'نامشخص',
        'MALE': 'مرد',
        'FEMALE': 'زن',
        'OTHER': 'دیگر',
        'PREFER_NOT_TO_SAY': 'ترجیح می‌دهم نگویم',
      },
      descriptionFa: 'برای تنظیم پیشنهادهای زیستی و سلامت',
      searchTerms: ['جنسیت', 'زن', 'مرد'],
    ),
    SettingDescriptor(
      key: 'user_age',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 25,
      labelFa: 'سن',
      group: SettingsGroup.identity,
      min: 10,
      max: 120,
      descriptionFa: 'محاسبه انرژی پایه و ظرفیت روزانه',
      searchTerms: ['سن', 'سال', 'تولد'],
    ),
    SettingDescriptor(
      key: 'user_avatar_path',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'تصویر پروفایل',
      group: SettingsGroup.identity,
      descriptionFa: 'مسیر محلی عکس ذخیره‌شده',
      searchTerms: ['عکس', 'آواتار', 'پروفایل', 'تصویر'],
    ),
    SettingDescriptor(
      key: 'app_mode',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'full',
      labelFa: 'حالت اپ (ساده / کامل)',
      group: SettingsGroup.identity,
      allowed: ['full', 'simple'],
      descriptionFa: 'حالت ساده فقط روتین‌ها و زمان‌سنج‌ها را نمایش می‌دهد',
      searchTerms: ['ساده', 'کامل', 'حالت', 'سبک'],
    ),
    SettingDescriptor(
      key: 'show_advanced_settings',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'نمایش تنظیمات پیشرفته',
      group: SettingsGroup.identity,
      descriptionFa:
          'نمایش کلیدها و گزینه‌های تخصصی و پیشرفته در صفحات تنظیمات',
      searchTerms: ['پیشرفته', 'ساده', 'حالت پیشرفته'],
    ),
    SettingDescriptor(
      key: 'identity_gender_asked',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'وضعیت پرسش جنسیت',
      group: SettingsGroup.identity,
      visibility: SettingVisibility.internal,
    ),
    SettingDescriptor(
      key: 'identity_age_asked',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'وضعیت پرسش سن',
      group: SettingsGroup.identity,
      visibility: SettingVisibility.internal,
    ),

    // ----------------------------------------------------
    // ۲. ماژول‌ها و بخش‌های برنامه (Modules)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'module_today_routines',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'امروز و روتین‌ها',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'هستهٔ اصلی پیگیری عادت‌ها و فعالیت‌های روزانه',
      searchTerms: ['امروز', 'روتین', 'عادت'],
    ),
    SettingDescriptor(
      key: 'module_calendar_journey',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'تقویم و سفر',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'نمای خط زمانی و برنامه‌ریزی ماهانه و هفتگی',
      searchTerms: ['تقویم', 'سفر', 'برنامه‌ریزی'],
    ),
    SettingDescriptor(
      key: 'module_assistant_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'دستیار هوشمند',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'دستیار همراه و پیشنهادهای خودمراقبتی',
      searchTerms: ['دستیار', 'هوش مصنوعی', 'چت'],
    ),
    SettingDescriptor(
      key: 'module_goals_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'اهداف و پیشرفت',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'تعریف اهداف کلیدی و شکستن آن‌ها به گام‌ها',
      searchTerms: ['هدف', 'اهداف', 'پیشرفت'],
    ),
    SettingDescriptor(
      key: 'module_study_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'درس و مطالعه',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'برنامهٔ مطالعه، سرفصل‌ها و مرور جعبه لایتنر',
      searchTerms: ['درس', 'مطالعه', 'کنکور', 'امتحان'],
    ),
    SettingDescriptor(
      key: 'module_courses_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'دوره‌های آموزشی',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'مدیریت جلسات و پیشرفت دوره‌های یادگیری',
      searchTerms: ['دوره', 'آموزش', 'کلاس'],
    ),
    SettingDescriptor(
      key: 'module_religion_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'عبادت و معنویت',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'اذان، اوقات شرعی، ادعیه و نمازهای مستحبی',
      searchTerms: ['نماز', 'عبادت', 'معنویت', 'دعا', 'اذان'],
    ),
    SettingDescriptor(
      key: 'module_sports_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'ورزش و تحرک',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'برنامه‌های تمرینی و فعالیت‌های بدنی',
      searchTerms: ['ورزش', 'تحرک', 'تمرین', 'بدنسازی'],
    ),
    SettingDescriptor(
      key: 'module_medicine_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'دارو و سلامت',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'یادآوری مصرف داروها و پیگیری سلامتی',
      searchTerms: ['دارو', 'سلامت', 'پزشکی', 'قرص'],
    ),
    SettingDescriptor(
      key: 'module_sleep_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'خواب و ریتم شبانه‌روزی',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'ثبت کیفیت خواب و همگام‌سازی ساعت زیستی',
      searchTerms: ['خواب', 'شب', 'ریتم زیستی', 'استراحت'],
    ),
    SettingDescriptor(
      key: 'module_cycle_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'چرخهٔ زیستی',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'پیگیری حریم‌دار چرخهٔ بانوان',
      searchTerms: ['چرخه', 'بانوان', 'پریود', 'سلامت زنان'],
    ),
    SettingDescriptor(
      key: 'module_energy_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'تحلیل انرژی',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'ارزیابی و تحلیل پنجره‌های انرژی در طول روز',
      searchTerms: ['انرژی', 'پالس', 'خستگی'],
    ),
    SettingDescriptor(
      key: 'module_progressive_habits_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'عادت‌های پیش‌رونده',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'افزایش تدریجی و خودکار گام‌های روتین',
      searchTerms: ['عادت', 'گام', 'پیشرونده'],
    ),
    SettingDescriptor(
      key: 'module_supplementary_sports_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'ورزش تکمیلی و کششی',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'تمرینات انعطاف‌پذیری و جانبی',
      searchTerms: ['ورزش', 'تکمیلی', 'کشش'],
    ),
    SettingDescriptor(
      key: 'module_notes_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'دفترچه و تجربه‌ها',
      group: SettingsGroup.modules,
      affectsAgenda: true,
      descriptionFa: 'یادداشت، ایده و درس‌هایی که از زندگی گرفته‌ای',
      searchTerms: ['یادداشت', 'دفترچه', 'تجربه', 'درس'],
    ),
    SettingDescriptor(
      key: 'systems_grouping_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'گروه‌بندی خودکار سیستم‌ها',
      group: SettingsGroup.modules,
      affectsAgenda: false,
      descriptionFa: 'دسته‌بندی کارت‌های سیستم‌ها در بخش‌های رشد، توازن و سلامت',
      searchTerms: ['گروه‌بندی', 'سیستم‌ها', 'چیدمان', 'کارت‌ها'],
    ),
    SettingDescriptor(
      key: 'systems_custom_order',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '["goals","notes","courses","konkur","religion","assistant","wellbeing","sports","medicine","cycle"]',
      labelFa: 'ترتیب سفارشی کارت‌های سیستم‌ها',
      group: SettingsGroup.modules,
      affectsAgenda: false,
      descriptionFa: 'ترتیب دلخواه کارت‌ها هنگام غیرفعال بودن گروه‌بندی',
      searchTerms: ['ترتیب', 'چیدمان'],
    ),

    // ----------------------------------------------------
    // ۳. اعلان‌ها و یادآوری‌ها (Notifications)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'notif_master_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'اعلان‌های سراسری',
      group: SettingsGroup.notifications,
      descriptionFa: 'فعال یا غیرفعال‌سازی همهٔ اعلان‌ها و یادآوری‌ها',
      aiWritable: true,
      searchTerms: ['اعلان', 'یادآوری', 'نوتیفیکیشن', 'پیام'],
    ),
    SettingDescriptor(
      key: 'notif_quiet_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'ساعات سکوت',
      group: SettingsGroup.notifications,
      descriptionFa: 'قطع موقت اعلان‌های غیراضطراری در ساعات مشخص',
      whyExplanationFa:
          'سکوت شبانه مانع از بیداری ناگهانی و قطع فازهای خواب عمیق می‌شود و پیام‌های غیرضروری را تا صبح به تعویق می‌اندازد.',
      aiWritable: true,
      searchTerms: ['سکوت', 'ساعت سکوت', 'شب', 'مزاحم نشوید'],
    ),
    SettingDescriptor(
      key: 'notif_quiet_start',
      type: SettingType.time,
      scope: SettingScope.db,
      defaultValue: '00:00',
      labelFa: 'شروع ساعات سکوت',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('notif_quiet_enabled'),
      descriptionFa: 'زمان آغاز عدم ارسال اعلان‌های غیراضطراری',
      searchTerms: ['شروع سکوت', 'زمان سکوت'],
    ),
    SettingDescriptor(
      key: 'notif_quiet_end',
      type: SettingType.time,
      scope: SettingScope.db,
      defaultValue: '07:00',
      labelFa: 'پایان ساعات سکوت',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('notif_quiet_enabled'),
      descriptionFa: 'زمان پایان سکوت و شروع مجدد اعلان‌ها',
      searchTerms: ['پایان سکوت', 'صبح'],
    ),
    SettingDescriptor(
      key: 'persistent_status_notification_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'اعلان دائمی وضعیت',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      descriptionFa: 'نمایش ویجت زندهٔ وظیفه جاری در نوار اعلان‌ها',
      searchTerms: ['اعلان دائم', 'استاتوس', 'نوار وضعیت'],
    ),
    SettingDescriptor(
      key: 'notif_tap_behavior',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'POPUP_FOR_ESSENTIAL',
      labelFa: 'رفتار ضربه روی اعلان',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('notif_master_enabled'),
      allowed: ['OPEN_APP', 'POPUP', 'POPUP_FOR_ESSENTIAL'],
      descriptionFa: 'تعیین واکنش سیستم هنگام لمس اعلان‌ها (باز کردن برنامه یا پنجره سریع)',
      searchTerms: ['ضربه', 'پاپ‌آپ', 'کلیک اعلان', 'رفتار ضربه'],
    ),
    SettingDescriptor(
      key: 'digest_mode',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'standard',
      labelFa: 'حالت خلاصه اعلان',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      allowed: ['standard', 'concise', 'grouped'],
      descriptionFa: 'نحوهٔ نمایش دسته‌ای پیام‌ها و یادآوری‌ها',
      searchTerms: ['خلاصه', 'دایجست', 'تجمیع پیام'],
    ),
    SettingDescriptor(
      key: 'coalescing_window_minutes',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 15,
      labelFa: 'بازهٔ تجمیع اعلان‌ها',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      min: 1,
      max: 60,
      descriptionFa: 'فاصله زمانی ادغام اعلان‌های نزدیک به هم (دقیقه)',
      searchTerms: ['تجمیع', 'دقیقه', 'پنجره'],
    ),
    SettingDescriptor(
      key: 'max_non_essential_per_hour',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 3,
      labelFa: 'سقف اعلان‌های غیراضطراری در ساعت',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      min: 1,
      max: 20,
      descriptionFa: 'حداکثر پیام‌های غیربحرانی در هر ۶۰ دقیقه',
      searchTerms: ['سقف اعلان', 'تعداد پیام', 'محدودیت'],
    ),
    SettingDescriptor(
      key: 'snooze_minutes',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 10,
      labelFa: 'زمان تعویق پیش‌فرض (دقیقه)',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('notif_master_enabled'),
      min: 1,
      max: 120,
      descriptionFa: 'فاصلهٔ زمانی تا یادآوری مجدد بعد از اسنوز',
      searchTerms: ['تعویق', 'اسنوز', 'یادآوری مجدد'],
    ),
    SettingDescriptor(
      key: 'snooze_max_defer_count',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 3,
      labelFa: 'حداکثر دفعات تعویق مجاز',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      min: 0,
      max: 10,
      descriptionFa: 'تعداد دفعات مجاز برای به تعویق انداختن یک روتین',
      searchTerms: ['حداکثر تعویق', 'دفعات اسنوز'],
    ),
    SettingDescriptor(
      key: 'notif_privacy_mode',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'redacted',
      labelFa: 'سطح حریم خصوصی اعلان‌ها',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      allowed: ['none', 'redacted', 'locked', 'hidden'],
      descriptionFa: 'نمایش متن مبدل، قفل با بیومتریک یا پنهان‌سازی کامل',
      searchTerms: ['حریم خصوصی', 'مبدل', 'قفل اعلان', 'امنیت'],
    ),
    SettingDescriptor(
      key: 'notif_biometric_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'قفل اثرانگشت برای اعلان‌های خصوصی',
      group: SettingsGroup.notifications,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('notif_master_enabled'),
      descriptionFa: 'الزام احراز هویت برای مشاهده متن اعلان‌های محرمانه',
      searchTerms: ['اثرانگشت', 'بیومتریک', 'قفل', 'احراز هویت'],
    ),

    // ----------------------------------------------------
    // ۴. ظاهر و زبان (Appearance & Locale)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'theme_mode',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'system',
      labelFa: 'حالت روشنایی تم',
      group: SettingsGroup.appearance,
      allowed: ['system', 'light', 'dark'],
      descriptionFa: 'تاریک، روشن یا هماهنگ با سیستم‌عامل',
      aiWritable: true,
      searchTerms: ['تم', 'تاریک', 'روشن', 'شب', 'روز'],
    ),
    SettingDescriptor(
      key: 'theme_palette',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'jade_noir',
      labelFa: 'پالت رنگی برنامه',
      group: SettingsGroup.appearance,
      allowed: [
        'jade_noir',
        'copper_dusk',
        'rosewood',
        'olive_sand',
        'graphite_champagne',
      ],
      descriptionFa: 'رنگ پایه و اتمسفر بصری محیط برنامه',
      searchTerms: ['پالت', 'رنگ', 'یشم', 'مس', 'رز', 'زیتون', 'گرافیت'],
    ),
    SettingDescriptor(
      key: 'theme_reduce_transparency',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'متریال شیشه‌ای (بلور)',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'افکت بلور و شفافیت در کارت‌ها و پس‌زمینه (خاموش برای گوشی‌های ضعیف‌تر)',
      searchTerms: ['شفافیت', 'ماتی', 'بلور', 'کنتراست', 'شیشه', 'glass'],
    ),
    SettingDescriptor(
      key: 'glass_blur_intensity',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 26,
      min: 0,
      max: 40,
      labelFa: 'میزان مات بودن شیشه (بلور)',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'تنظیم شدت محوشدگی و ماتی پس‌زمینه پشت متریال شیشه‌ای',
      searchTerms: ['بلور', 'مات', 'ماتی', 'شیشه', 'blur'],
    ),
    SettingDescriptor(
      key: 'glass_opacity_percent',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 35,
      min: 10,
      max: 85,
      labelFa: 'میزان شفافیت شیشه',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'تنظیم درصد غلظت و شفافیت سطح شیشه‌ای',
      searchTerms: ['شفافیت', 'غلظت', 'شیشه', 'opacity'],
    ),
    SettingDescriptor(
      key: 'theme_true_black',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'سیاه خالص (OLED)',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.advanced,
      requiresRestart: true,
      descriptionFa: 'استفاده از سیاه عمیق جهت صرفه‌جویی در باتری',
      searchTerms: ['سیاه', 'امولد', 'oled', 'تاریک خالص'],
    ),
    SettingDescriptor(
      key: 'ui_text_scale',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 100,
      min: 85,
      max: 140,
      labelFa: 'اندازهٔ متن',
      group: SettingsGroup.appearance,
      requiresRestart: false,
      descriptionFa: 'تنظیم مقیاس و بزرگی متن‌ها در سراسر برنامه',
      searchTerms: [
        'اندازه متن',
        'فونت',
        'بزرگنمایی',
        'درشتی',
        'ریزی',
        'چگالی',
        'فشردگی',
        'بزرگی المان',
        'دسترس‌پذیری',
        'کم‌بینا',
      ],
    ),
    SettingDescriptor(
      key: 'ui_text_follow_os',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'پیروی از اندازه فونت سیستم',
      group: SettingsGroup.appearance,
      requiresRestart: false,
      descriptionFa: 'اعمال مقیاس فونت تنظیم‌شده در سیستم‌عامل دستگاه',
      searchTerms: [
        'اندازه متن',
        'فونت',
        'بزرگنمایی',
        'درشتی',
        'ریزی',
        'چگالی',
        'فشردگی',
        'بزرگی المان',
        'دسترس‌پذیری',
        'کم‌بینا',
      ],
    ),
    SettingDescriptor(
      key: 'ui_density',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'comfortable',
      allowed: ['compact', 'comfortable', 'spacious', 'xl'],
      labelFa: 'چگالی و اندازهٔ المان‌ها',
      group: SettingsGroup.appearance,
      requiresRestart: false,
      descriptionFa: 'تنظیم فواصل، دکمه‌ها و بزرگی اجزای رابط کاربری',
      searchTerms: [
        'اندازه متن',
        'فونت',
        'بزرگنمایی',
        'درشتی',
        'ریزی',
        'چگالی',
        'فشردگی',
        'بزرگی المان',
        'دسترس‌پذیری',
        'کم‌بینا',
      ],
    ),
    SettingDescriptor(
      key: 'locale',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'fa',
      labelFa: 'زبان برنامه',
      group: SettingsGroup.appearance,
      requiresRestart: true,
      allowed: ['fa', 'en'],
      descriptionFa: 'فارسی یا انگلیسی',
      searchTerms: ['زبان', 'فارسی', 'انگلیسی', 'locale'],
    ),
    SettingDescriptor(
      key: 'haptic_feedback_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'بازخورد لرزشی (هپتیک)',
      group: SettingsGroup.appearance,
      descriptionFa: 'لرزش ملایم هنگام لمس دکمه‌ها و ثبت رویدادها',
      searchTerms: ['لرزش', 'هپتیک', 'ویبره', 'بازخورد'],
    ),

    // ----------------------------------------------------
    // ۵. دستیار و حریم خصوصی (Assistant & Privacy)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'ai_mode',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'ritmo_server',
      labelFa: 'حالت اتصال هوش مصنوعی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      allowed: ['ritmo_server', 'personal_key'],
      descriptionFa: 'استفاده از سرور امن ریتمو یا کلید شخصی کاربر',
      searchTerms: ['هوش مصنوعی', 'سرور', 'کلید شخصی', 'api'],
    ),
    SettingDescriptor(
      key: 'ai_provider_preset',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'chatgpt_web',
      labelFa: 'سرویس‌دهنده هوش مصنوعی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      allowed: ['chatgpt_web', 'opencode', 'zhipu', 'openrouter', 'cloudflare', 'groq', 'local', 'custom'],
      descriptionFa: 'انتخاب ارائه‌دهنده مدل هوش مصنوعی',
      searchTerms: ['ارائه‌دهنده', 'وب چت‌جی‌پی‌تی', 'chatgpt web', 'ژیپو', 'کلودفلر', 'اوپن روتر'],
    ),
    SettingDescriptor(
      key: 'ai_base_url',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'آدرس سرویس‌دهنده هوش مصنوعی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('ai_mode', 'personal_key'),
      descriptionFa: 'Endpoint اختصاصی برای ارتباط چت',
      searchTerms: ['آدرس هوش مصنوعی', 'url', 'endpoint'],
    ),
    SettingDescriptor(
      key: 'ai_api_key',
      type: SettingType.text,
      scope: SettingScope.secure,
      defaultValue: '',
      labelFa: 'کلید دسترسی هوش مصنوعی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      isResettable: false,
      dependsOn: SettingCondition('ai_mode', 'personal_key'),
      descriptionFa: 'ذخیره رمزنگاری‌شده در حافظه امن دستگاه',
      searchTerms: ['کلید api', 'api key', 'رمز هوش مصنوعی'],
    ),
    SettingDescriptor(
      key: 'ai_model',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'نام مدل هوش مصنوعی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('ai_mode', 'personal_key'),
      descriptionFa: 'شناسه مدل مورد استفاده برای پاسخگویی',
      searchTerms: ['مدل', 'model', 'glm', 'llama'],
    ),
    SettingDescriptor(
      key: 'ai_timeout',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 60000,
      labelFa: 'مهلت پاسخ هوش مصنوعی (میلی‌ثانیه)',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      min: 5000,
      max: 300000,
      descriptionFa: 'تایم‌اوت ارتباط شبکه با سرویس‌دهنده',
      searchTerms: ['تایم اوت', 'مهلت پاسخ', 'زمان اتصال'],
    ),
    SettingDescriptor(
      key: 'ai_memory_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'حافظهٔ شناختی دستیار',
      group: SettingsGroup.assistant,
      descriptionFa: 'به خاطر سپردن ترجیحات و عادات کاربر',
      searchTerms: ['حافظه', 'شناختی', 'یادگیری'],
    ),
    SettingDescriptor(
      key: 'ai_memory_implicit_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'یادگیری خودکار و ضمنی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('ai_memory_enabled'),
      descriptionFa: 'استخراج هوشمند الگوی روزمره بدون نیاز به ثبت دستی',
      searchTerms: ['یادگیری خودکار', 'ضمنی', 'عادات'],
    ),
    SettingDescriptor(
      key: 'assistant_cloud_consent',
      type: SettingType.boolean,
      scope: SettingScope.prefs,
      defaultValue: true,
      labelFa: 'رضایت‌نامه پردازش ابری',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'مجوز ارسال خلاصه‌های متنی به سرویس هوش مصنوعی',
      searchTerms: ['رضایت', 'ابر', 'حریم خصوصی', 'امنیت داده'],
    ),
    SettingDescriptor(
      key: 'assistant_briefing_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'خلاصه‌ساز روزانه دستیار',
      group: SettingsGroup.assistant,
      descriptionFa: 'ارائه خلاصه کارهای روز در ابتدای صبح',
      searchTerms: ['خلاصه روز', 'بریفینگ', 'صبحگاهی'],
    ),
    SettingDescriptor(
      key: 'assistant_proactive_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'پیشنهادهای پیش‌دستانه',
      group: SettingsGroup.assistant,
      descriptionFa: 'ارائه پیشنهاد استراحت یا فعالیت بر اساس سطح انرژی',
      searchTerms: ['پیشنهاد', 'فعال', 'هوشمند'],
    ),
    SettingDescriptor(
      key: 'gentleness_level',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'medium',
      labelFa: 'لحن و نرمی دستیار',
      group: SettingsGroup.assistant,
      allowed: ['gentle', 'medium', 'strict'],
      descriptionFa: 'میزان سخت‌گیری و سبک پیام‌های یادآوری',
      whyExplanationFa:
          'لحن دستیار نحوه برخورد سیستم هنگام عقب افتادن برنامه‌ها را تنظیم می‌کند؛ لحن ملایم استرس روانی را کاهش داده و لحن قاطع از اهمال‌کاری جلوگیری می‌کند.',
      searchTerms: ['لحن', 'سختی', 'سخت‌گیری', 'انعطاف'],
    ),
    SettingDescriptor(
      key: 'daily_capacity_minutes',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 480,
      labelFa: 'ظرفیت کار روزانه (دقیقه)',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      min: 60,
      max: 1440,
      descriptionFa: 'حداکثر دقایق تخصیص داده شده به فعالیت‌های تمرکزی',
      whyExplanationFa:
          'مغز انسان توان تمرکزی محدودی در طول شبانه‌روز دارد. این سقف مانع از فشردگی بیش‌ازحد کارهای تمرکزی و فرسودگی ذهنی می‌شود.',
      searchTerms: ['ظرفیت', 'توان', 'ساعت کار'],
    ),
    SettingDescriptor(
      key: 'sleep_target_wake',
      type: SettingType.time,
      scope: SettingScope.db,
      defaultValue: '07:00',
      labelFa: 'زمان هدف بیداری',
      group: SettingsGroup.assistant,
      affectsAgenda: true,
      descriptionFa: 'آغاز خط زمانی روز در تقویم و برنامه‌ریز',
      whyExplanationFa:
          'تقویم هوشمند آغاز روز و بلوک‌های تمرکز صبحگاهی را با ساعت فیزیولوژیک بیداری شما تراز می‌کند.',
      searchTerms: ['بیداری', 'صبح', 'طلوع', 'خواب'],
    ),
    SettingDescriptor(
      key: 'sleep_target_bedtime',
      type: SettingType.time,
      scope: SettingScope.db,
      defaultValue: '23:30',
      labelFa: 'زمان هدف خواب',
      group: SettingsGroup.assistant,
      affectsAgenda: true,
      descriptionFa: 'پایان فعالیت‌های فعال و بسته شدن پرونده روز',
      whyExplanationFa:
          'برای تثبیت ریتم سیرکادین و ترشح ملاتونین، وظایف قبل از این زمان بسته شده تا ذهن آماده استراحت کامل شود.',
      searchTerms: ['خواب', 'شب', 'استراحت'],
    ),
    SettingDescriptor(
      key: 'sleep_target_duration_minutes',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 450,
      labelFa: 'مدت زمان مطلوب خواب (دقیقه)',
      group: SettingsGroup.assistant,
      affectsAgenda: true,
      min: 180,
      max: 900,
      descriptionFa: 'میزان خواب ایده‌آل روزانه برای شارژ کامل انرژی',
      whyExplanationFa:
          'برای محاسبه شاخص تعادل و بررسی کسری خواب هفتگی مورد استفاده قرار می‌گیرد.',
      searchTerms: ['خواب', 'مدت خواب', 'کسر خواب'],
    ),
    SettingDescriptor(
      key: 'assistant_can_modify_settings',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'اجازه به دستیار برای تغییر تنظیمات',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      descriptionFa:
          'اجازه به دستیار هوشمند برای اعمال تغییرات مجاز (مانند ساعات خواب و اعلان‌ها)',
      searchTerms: ['تغییر تنظیمات', 'دستیار', 'مجوز هوش مصنوعی', 'هوشمند'],
    ),
    SettingDescriptor(
      key: 'ai_forbidden_keys',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'کلیدهای ممنوعه برای تغییر توسط دستیار',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      descriptionFa:
          'فهرست کلیدهای جداشده با کاما که دستیار حق تغییر آن‌ها را ندارد',
      searchTerms: ['ممنوعه', 'بلک لیست', 'لیست سیاه دستیار'],
    ),
    SettingDescriptor(
      key: 'ai_local_processing_only',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'پردازش هوش مصنوعی صرفاً محلی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      descriptionFa:
          'عدم ارسال داده‌های شناختی و پردازش‌ها به سرویس‌های ابری خارج از دستگاه',
      whyExplanationFa:
          'برای بیشترین میزان محرمانگی، تمام تحلیل‌های رفتارشناسی و حافظه دستیار در داخل حافظه محلی دستگاه شما باقی می‌مانند.',
      searchTerms: ['محلی', 'آفلاین', 'حریم خصوصی', 'local'],
    ),
    SettingDescriptor(
      key: 'ai_auto_purge_days',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 30,
      labelFa: 'پاکسازی خودکار تاریخچه دستیار (روز)',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.advanced,
      min: 0,
      max: 365,
      descriptionFa:
          'حذف خودکار تاریخچه پردازش و گفتگوها پس از تعداد روز مشخص (۰ برای دائمی)',
      searchTerms: ['پاکسازی', 'حذف سوابق', 'انقضا', 'purge'],
    ),

    // ----------------------------------------------------
    // ۶. داده و پشتیبان (Data & Backup)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'auto_backup_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'پشتیبان‌گیری خودکار',
      group: SettingsGroup.dataBackup,
      descriptionFa: 'ایجاد نسخه پشتیبان دوره‌ای از اطلاعات برنامه',
      searchTerms: ['پشتیبان', 'بکاپ', 'پشتیبان‌گیری', 'backup'],
    ),
    SettingDescriptor(
      key: 'backup_frequency_days',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 7,
      labelFa: 'دورهٔ پشتیبان‌گیری خودکار (روز)',
      group: SettingsGroup.dataBackup,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('auto_backup_enabled'),
      min: 1,
      max: 30,
      descriptionFa: 'فاصله زمانی بین هر بار نسخه پشتیبان خودکار',
      searchTerms: ['دوره بکاپ', 'فاصله پشتیبان', 'backup'],
    ),
    SettingDescriptor(
      key: 'crash_reports_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'ثبت گزارش خطاهای سیستم',
      group: SettingsGroup.dataBackup,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'کمک به بهبود پایداری برنامه با ذخیره محلی کرش‌ها',
      searchTerms: ['گزارش خطا', 'کرش', 'لاگ'],
    ),

    // ----------------------------------------------------
    // ۷. امنیت و قفل برنامه (Security)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'app_lock_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'قفل کلی برنامه',
      group: SettingsGroup.security,
      descriptionFa: 'نیاز به ورود رمز یا بیومتریک هنگام باز کردن ریتمو',
      searchTerms: ['قفل', 'امنیت', 'رمز عبور', 'حفاظت'],
    ),
    SettingDescriptor(
      key: 'app_lock_password',
      type: SettingType.text,
      scope: SettingScope.secure,
      defaultValue: '',
      labelFa: 'رمز قفل برنامه',
      group: SettingsGroup.security,
      isResettable: false,
      dependsOn: SettingCondition('app_lock_enabled'),
      descriptionFa: 'رمز عددی برای باز کردن برنامه',
      searchTerms: ['پین', 'رمز', 'پسورد'],
    ),
    SettingDescriptor(
      key: 'app_use_device_lock',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'استفاده از قفل صفحه دستگاه',
      group: SettingsGroup.security,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('app_lock_enabled'),
      descriptionFa: 'استفاده از الگو، پین یا رمز عبور اصلی گوشی',
      searchTerms: ['قفل گوشی', 'پین سیستم', 'الگو'],
    ),
    SettingDescriptor(
      key: 'app_biometric_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'ورود با اثر انگشت / چهره',
      group: SettingsGroup.security,
      dependsOn: SettingCondition('app_lock_enabled'),
      descriptionFa: 'بازگشایی سریع با حسگرهای بیومتریک گوشی',
      searchTerms: ['اثر انگشت', 'تشخیص چهره', 'بیومتریک'],
    ),
    SettingDescriptor(
      key: 'app_lock_timeout_seconds',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 300,
      labelFa: 'مهلت قفل خودکار',
      group: SettingsGroup.security,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('app_lock_enabled'),
      min: -1,
      max: 3600,
      descriptionFa:
          'مدت زمان خروج از برنامه تا فعال شدن مجدد قفل (ثانیه؛ ۱- برای هرگز)',
      searchTerms: ['زمان قفل', 'تایم اوت قفل', 'قفل خودکار'],
    ),
    SettingDescriptor(
      key: 'cycle_lock_password',
      type: SettingType.text,
      scope: SettingScope.secure,
      defaultValue: '',
      labelFa: 'رمز اختصاصی بخش چرخه زیستی',
      group: SettingsGroup.security,
      isResettable: false,
      dependsOn: SettingCondition('module_cycle_enabled'),
      descriptionFa: 'رمز مجزا برای ورود به بخش خصوصی چرخه سلامت بانوان',
      searchTerms: ['رمز چرخه', 'قفل چرخه', 'حریم خصوصی'],
    ),
    SettingDescriptor(
      key: 'cycle_biometric_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'بیومتریک اختصاصی چرخه',
      group: SettingsGroup.security,
      visibility: SettingVisibility.advanced,
      dependsOn: SettingCondition('module_cycle_enabled'),
      descriptionFa: 'امکان بازگشایی بخش چرخه با اثر انگشت',
      searchTerms: ['اثر انگشت چرخه', 'بیومتریک چرخه'],
    ),
    SettingDescriptor(
      key: 'screen_security_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'امنیت صفحه و پیش‌نمای برنامه',
      group: SettingsGroup.security,
      visibility: SettingVisibility.advanced,
      descriptionFa:
          'جلوگیری از اسکرین‌شات و مخفی‌سازی محتوا هنگام باز کردن اپ سوئیچر',
      searchTerms: [
        'اسکرین شات',
        'امنیت صفحه',
        'اپ سوئیچر',
        'task switcher',
        'مخفی سازی',
      ],
    ),
    // Prompt 063: Task Settings (T-38)
    SettingDescriptor(
      key: 'tasks_completion_sound_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'صدای کوتاه هنگام تیک زدن',
      group: SettingsGroup.notifications,
      descriptionFa: 'پخش صدای بومی سیستم هنگام انجام کار یا زیرگام',
      searchTerms: ['صدای تیک', 'صدای تکمیل', 'صدا'],
    ),
    SettingDescriptor(
      key: 'tasks_daily_nudge_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'یادآور مرور کارهای امروز',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('notif_master_enabled'),
      descriptionFa: 'ارسال اعلان یادآوری روزانه برای مرور کارهای امروز',
      searchTerms: ['یادآور روزانه', 'برنامه‌ریزی روزانه', 'اعلان'],
    ),
    SettingDescriptor(
      key: 'tasks_daily_nudge_time',
      type: SettingType.time,
      scope: SettingScope.db,
      defaultValue: '08:30',
      labelFa: 'ساعت یادآور روزانه',
      group: SettingsGroup.notifications,
      dependsOn: SettingCondition('tasks_daily_nudge_enabled'),
      descriptionFa: 'زمان ارسال اعلان یادآوری روزانه',
      searchTerms: ['ساعت یادآور', 'زمان برنامه'],
    ),
    SettingDescriptor(
      key: 'tasks_hide_completed',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'مخفی کردن کارهای انجام‌شده',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'پنهان کردن کارهای تکمیل‌شده از فهرست کارهای ساده',
      searchTerms: ['مخفی کردن', 'تکمیل شده', 'کارهای انجام شده'],
    ),

    // ----------------------------------------------------
    // K47: تنظیمات تقویم (Calendar)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'calendar_default_scale',
      type: SettingType.enumeration,
      scope: SettingScope.db,
      defaultValue: 'agenda',
      labelFa: 'نمای پیش‌فرض تقویم',
      group: SettingsGroup.calendar,
      allowed: ['agenda', 'day', 'week', 'month', 'year'],
      optionLabelsFa: {
        'agenda': 'برنامه (رویدادها و کارها)',
        'day': 'روزانه (خط زمان)',
        'week': 'هفتگی',
        'month': 'ماهانه',
        'year': 'سالانه',
      },
      descriptionFa:
          'مقیاس اولیه تقویم هنگام ورود به برنامه (برنامه، روز، هفته، ماه، سال)',
      searchTerms: ['نمای تقویم', 'پیش‌فرض تقویم', 'مقیاس'],
    ),
    SettingDescriptor(
      key: 'calendar_show_tasks',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش کارها در تقویم',
      group: SettingsGroup.calendar,
      affectsAgenda: true,
      descriptionFa:
          'نمایش کارهای ساده و گام‌های اهداف در خط زمان و نمای برنامه',
      searchTerms: ['نمایش کارها', 'تسک', 'کارها'],
    ),
    SettingDescriptor(
      key: 'calendar_show_events',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش رویدادها در تقویم',
      group: SettingsGroup.calendar,
      affectsAgenda: true,
      descriptionFa: 'نمایش رویدادهای موقت و زمان‌دار در خط زمان و نمای برنامه',
      searchTerms: ['نمایش رویدادها', 'رویداد', 'ایونت', 'جلسه'],
    ),
    SettingDescriptor(
      key: 'calendar_show_commitments',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش تعهدها و برنامه‌ریزی در تقویم',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa:
          'نمایش تعهدها و تخصیص‌های چرخهٔ برنامه‌ریزی در خط زمان و نمای برنامه',
      searchTerms: ['تعهد', 'برنامه‌ریزی', 'تخصیص', 'اهداف'],
    ),
    SettingDescriptor(
      key: 'calendar_show_appointments',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش نوبت‌های سلامت در تقویم',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa:
          'نمایش ویزیت‌های پزشک و واکسیناسیون در خط زمان و نمای برنامه',
      searchTerms: ['پزشک', 'ویزیت', 'واکسن', 'سلامت', 'دکتر'],
    ),
    SettingDescriptor(
      key: 'calendar_show_sleep_band',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش باند خواب در خط زمان',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa: 'نمایش سایه و بازهٔ خواب برنامه‌ریزی‌شده در خط زمان تقویم',
      searchTerms: ['خواب', 'باند خواب', 'سایه شب', 'استراحت'],
    ),
    SettingDescriptor(
      key: 'show_cycle_in_calendar',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'نمایش فاز چرخه در تقویم',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa:
          'نمایش روزهای پیش‌بینی‌شده و فاز چرخه در تقویم (نیازمند رضایت صریح)',
      searchTerms: ['چرخه', 'پریود', 'بانوان', 'فاز چرخه'],
    ),
    SettingDescriptor(
      key: 'calendar_overdue_lookback_days',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 14,
      labelFa: 'بازهٔ بازگشت کارهای معوقه در تقویم (روز)',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      min: 0,
      max: 365,
      unitFa: 'روز',
      descriptionFa:
          'تعداد روزهای گذشته برای جستجو و نمایش کارهای انجام‌نشده در نمای امروز',
      searchTerms: ['معوقه', 'کارهای عقب‌افتاده', 'تسک', 'بازه'],
    ),
    SettingDescriptor(
      key: 'calendar_show_worship_obligatory',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش نمازهای واجب در تقویم',
      group: SettingsGroup.calendar,
      affectsAgenda: true,
      descriptionFa: 'نمایش اوقات و وضعیت نمازهای یومیه در خط زمان تقویم',
      searchTerms: ['نماز', 'واجب', 'عبادت', 'اوقات شرعی'],
    ),
    SettingDescriptor(
      key: 'calendar_show_worship_mustahab',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش مستحبات و اذکار در تقویم',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa:
          'نمایش کارهای مستحب، تعقیبات و اذکار روزانه در خط زمان و شناورهای تقویم',
      searchTerms: ['مستحب', 'ذکر', 'قرآن', 'تعقیبات', 'زیارت'],
    ),
    SettingDescriptor(
      key: 'calendar_show_worship_qada',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'نمایش قضای عبادات در تقویم',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa: 'نمایش برنامه‌ریزی ادای نماز و روزه قضا در خط زمان تقویم',
      searchTerms: ['قضا', 'بدهی عبادت', 'نماز قضا'],
    ),
    SettingDescriptor(
      key: 'calendar_compress_recurring',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'فشرده‌سازی تکرارها در نمای برنامه',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      affectsAgenda: true,
      descriptionFa:
          'تجمیع روتین‌ها و کارهای تکرارشونده روزانه در باکت‌های دور تقویم',
      searchTerms: ['فشرده‌سازی', 'تکرارها', 'روتین', 'تجمیع'],
    ),
    SettingDescriptor(
      key: 'calendar_show_occasions',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش مناسبت‌ها و تعطیلات',
      group: SettingsGroup.calendar,
      affectsAgenda: true,
      descriptionFa: 'نمایش نوار مناسبت‌های رسمی و تعطیلات در تقویم',
      searchTerms: ['مناسبت', 'تعطیلات', 'مناسبت‌ها'],
    ),
    SettingDescriptor(
      key: 'calendar_show_hijri',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'نمایش تاریخ قمری',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.advanced,
      descriptionFa: 'نمایش تاریخ هجری قمری در سربرگ روز و مناسبت‌های مذهبی',
      searchTerms: ['قمری', 'هجری', 'تاریخ قمری'],
    ),
    SettingDescriptor(
      key: 'calendar_morning_brief_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'گزارش صبحگاهی',
      group: SettingsGroup.calendar,
      descriptionFa: 'تولید و نمایش خلاصه وضعیت صبحگاهی برای شروع روز',
      searchTerms: ['گزارش صبحگاهی', 'خلاصه روز', 'مورنینگ بریف'],
    ),

    // ----------------------------------------------------
    // ۹. کلیدهای یکپارچه‌سازی سیستمی و مهاجرت (Pattern P-E)
    // ----------------------------------------------------
    SettingDescriptor(
      key: 'goals_view_mode',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: 'timeline',
      labelFa: 'حالت نمایش اهداف',
      group: SettingsGroup.modules,
      visibility: SettingVisibility.internal,
      descriptionFa: 'حالت نمایش انتخابی در ماژول اهداف (timeline / matrix / list)',
    ),
    SettingDescriptor(
      key: 'onboarding_completed',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'اتمام راه‌اندازی اولیه',
      group: SettingsGroup.identity,
      visibility: SettingVisibility.internal,
      descriptionFa: 'وضعیت تکمیل فرایند آنبوردینگ کاربر',
    ),
    SettingDescriptor(
      key: 'ss_default_rest_seconds',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 60,
      labelFa: 'زمان استراحت پیش‌فرض ورزشی (ثانیه)',
      group: SettingsGroup.modules,
      min: 0,
      max: 600,
      descriptionFa: 'مدت زمان استراحت بین ست‌ها در تمرینات ورزشی',
    ),
    SettingDescriptor(
      key: 'ss_tts_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'راهنمای صوتی تمرینات ورزشی',
      group: SettingsGroup.modules,
      descriptionFa: 'اعلام صوتی شروع و پایان ست‌ها و حرکات ورزشی',
    ),
    SettingDescriptor(
      key: 'ss_metric_unit',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'واحد اندازه‌گیری متریک',
      group: SettingsGroup.modules,
      descriptionFa: 'نمایش وزن و فاصله با واحدهای متریک (کیلوگرم / کیلومتر)',
    ),
    SettingDescriptor(
      key: 'replan_suggest_count',
      type: SettingType.integer,
      scope: SettingScope.db,
      defaultValue: 0,
      labelFa: 'شمارنده پیشنهادهای بازبرنامه‌ریزی',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.internal,
      descriptionFa: 'تعداد پیشنهادهای بازبرنامه‌ریزی ارائه شده در روز جاری',
    ),
    SettingDescriptor(
      key: 'assistant_cloud_consent',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false, // Opt-in default for strict privacy
      labelFa: 'رضایت اتصال به هوش ابری',
      group: SettingsGroup.assistant,
      descriptionFa: 'ارسال ایمن داده‌های پردازش به مدل‌های ابری هوش مصنوعی',
    ),
    SettingDescriptor(
      key: 'ai_deep_analysis_consent',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'رضایت تحلیل عمیق هوش مصنوعی',
      group: SettingsGroup.assistant,
      descriptionFa: 'مجوز تحلیل عمیق و ارائه بینش‌های ترکیبی سلامت و سبک زندگی',
    ),
    SettingDescriptor(
      key: 'weekly_backup_enabled',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'پشتیبان‌گیری هفتگی خودکار',
      group: SettingsGroup.dataBackup,
      descriptionFa: 'پشتیبان‌گیری خودکار هفتگی از اطلاعات پایگاه داده',
    ),
    SettingDescriptor(
      key: 'planner_draft_text',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'پیش‌نویس متنی برنامه‌ریز',
      group: SettingsGroup.calendar,
      visibility: SettingVisibility.internal,
      descriptionFa: 'متن پیش‌نویس ذخیره‌شده در برنامه‌ریز ورودی طبیعی',
    ),
    SettingDescriptor(
      key: 'ai_deep_analysis_result_v1',
      type: SettingType.text,
      scope: SettingScope.db,
      defaultValue: '',
      labelFa: 'کش نتیجه تحلیل عمیق',
      group: SettingsGroup.assistant,
      visibility: SettingVisibility.internal,
      descriptionFa: 'کش آخرین نتیجه تحلیل عمیق سلامت و ریتم',
    ),
    SettingDescriptor(
      key: 'systems_custom_order_banner_dismissed',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: false,
      labelFa: 'رد کردن بنر ترتیب سفارشی',
      group: SettingsGroup.appearance,
      visibility: SettingVisibility.internal,
      descriptionFa: 'وضعیت بسته شدن بنر راهنمای ترتیب سفارشی ماژول‌ها',
    ),
  ];

  static final Map<String, SettingDescriptor> _byKey = {
    for (final d in all) d.key: d,
  };

  static final Map<SettingsGroup, List<SettingDescriptor>> _byGroup = {
    for (final g in SettingsGroup.values)
      g: all.where((d) => d.group == g).toList(growable: false),
  };

  static int get count => all.length;

  static SettingDescriptor? find(String key) => _byKey[key];

  static List<SettingDescriptor> byGroup(SettingsGroup g) =>
      _byGroup[g] ?? const [];

  static List<SettingDescriptor> userVisibleByGroup(
    SettingsGroup g, {
    bool includeAdvanced = true,
  }) {
    final list = _byGroup[g] ?? const [];
    return list
        .where((d) {
          if (d.visibility == SettingVisibility.internal) return false;
          if (!includeAdvanced && d.visibility == SettingVisibility.advanced)
            return false;
          return true;
        })
        .toList(growable: false);
  }

  static List<SettingDescriptor> searchable() {
    return all
        .where((d) => d.visibility != SettingVisibility.internal)
        .toList(growable: false);
  }

  static List<String> get aiWritableKeys {
    return all
        .where((d) => d.aiWritable)
        .map((d) => d.key)
        .toList(growable: false);
  }
}
