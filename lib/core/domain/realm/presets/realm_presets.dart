import 'package:ritmo/core/domain/realm/realm_mode.dart';

/// Pre-configured 1-tap template for time realms (F-05).
class RealmPreset {
  const RealmPreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    required this.description,
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final RealmMode mode;
  final String startTime;
  final String endTime;
  final Set<int> daysOfWeek;
  final String description;

  /// The 6 canonical 1-tap realm presets (F-05).
  static const List<RealmPreset> standardPresets = [
    // 1. Work / Career
    RealmPreset(
      id: 'preset_work',
      name: 'کار و حرفه',
      icon: '💼',
      colorHex: '#3B82F6',
      mode: RealmMode.focus,
      startTime: '08:30',
      endTime: '16:30',
      daysOfWeek: {6, 7, 1, 2, 3}, // Sat to Wed
      description: 'تمرکز کاری بدون حواس‌پرتی',
    ),
    // 2. Family & Home
    RealmPreset(
      id: 'preset_family',
      name: 'خانواده و خانه',
      icon: '👨‍👩‍👧',
      colorHex: '#10B981',
      mode: RealmMode.silent,
      startTime: '18:00',
      endTime: '22:00',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7}, // Every day
      description: 'حضور آرام و بدون نوتیفیکیشن',
    ),
    // 3. Study / Learning
    RealmPreset(
      id: 'preset_study',
      name: 'مطالعه و یادگیری',
      icon: '📚',
      colorHex: '#8B5CF6',
      mode: RealmMode.focus,
      startTime: '16:30',
      endTime: '18:30',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      description: 'جلسات عمیق پژوهش و کنکور',
    ),
    // 4. Fitness / Health
    RealmPreset(
      id: 'preset_fitness',
      name: 'ورزش و تندرستی',
      icon: '🏋️',
      colorHex: '#F59E0B',
      mode: RealmMode.normal,
      startTime: '07:00',
      endTime: '08:30',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      description: 'تمرینات بدنی و دویدن',
    ),
    // 5. Worship / Spirituality
    RealmPreset(
      id: 'preset_worship',
      name: 'عبادت و معنویت',
      icon: '🕌',
      colorHex: '#059669',
      mode: RealmMode.silent,
      startTime: '12:30',
      endTime: '13:30',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      description: 'نماز و خلوت معنوی',
    ),
    // 6. Sleep / Rest
    RealmPreset(
      id: 'preset_sleep',
      name: 'خواب و ریکاوری',
      icon: '😴',
      colorHex: '#6366F1',
      mode: RealmMode.silent,
      startTime: '23:00',
      endTime: '06:30',
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      description: 'آرامش شبانه و شارژ مجدد بدن',
    ),
  ];
}
