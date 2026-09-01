import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// Representation of a lightweight, desk-friendly mobility stretch exercise.
class BreakMobilityExercise {
  final String id;
  final String nameFa;
  final String descriptionFa;
  final int durationSeconds;
  final String targetArea;
  final String emoji;

  const BreakMobilityExercise({
    required this.id,
    required this.nameFa,
    required this.descriptionFa,
    this.durationSeconds = 30,
    required this.targetArea,
    this.emoji = '🧘',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameFa': nameFa,
      'descriptionFa': descriptionFa,
      'durationSeconds': durationSeconds,
      'targetArea': targetArea,
      'emoji': emoji,
    };
  }

  factory BreakMobilityExercise.fromMap(Map<String, dynamic> map) {
    return BreakMobilityExercise(
      id: map['id'] as String? ?? 'stretch_custom',
      nameFa: map['nameFa'] as String? ?? map['name'] as String? ?? 'کشش ملایم',
      descriptionFa: map['descriptionFa'] as String? ??
          map['instructions'] as String? ??
          'حرکت را آرام و هماهنگ با تنفس انجام دهید.',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 30,
      targetArea: map['targetArea'] as String? ?? 'گردن و بالاتنه',
      emoji: map['emoji'] as String? ?? '🧘',
    );
  }
}

/// Core domain engine for resolving study and work break mobility exercises.
/// Adheres strictly to Constitution Law 16 (Engines Never Talk Directly) and Law 18.
class RitmoBreakMobilityEngine {
  const RitmoBreakMobilityEngine();

  static const List<BreakMobilityExercise> _curatedFallbackExercises = [
    BreakMobilityExercise(
      id: 'desk_neck_side_stretch',
      nameFa: 'کشش جانبی گردن',
      descriptionFa:
          'سر را به آرامی به سمت شانه راست خم کنید و با دست راست فشار بسیار ملایمی وارد کنید. ۱۵ ثانیه نگه دارید و سپس برای سمت چپ تکرار کنید.',
      durationSeconds: 30,
      targetArea: 'عضلات گردن و شانه',
      emoji: '💆',
    ),
    BreakMobilityExercise(
      id: 'desk_shoulder_rolls',
      nameFa: 'چرخش شانه و باز کردن سینه',
      descriptionFa:
          'شانه‌ها را با حرکتی دایره‌ای و عمیق ۵ بار به عقب و سپس ۵ بار به جلو بچرخانید تا گرفتگی ذوزنقه‌ای رفع شود.',
      durationSeconds: 30,
      targetArea: 'شانه و کتف',
      emoji: '🔄',
    ),
    BreakMobilityExercise(
      id: 'desk_seated_twist',
      nameFa: 'چرخش ستون فقرات نشسته',
      descriptionFa:
          'پشت میز صاف بنشینید، بالاتنه را به سمت راست بچرخانید و پشت صندلی را لمس کنید. ۱۵ ثانیه مکث کنید و سپس به سمت چپ بچرخید.',
      durationSeconds: 30,
      targetArea: 'ستون فقرات و کمر',
      emoji: '🪑',
    ),
    BreakMobilityExercise(
      id: 'desk_wrist_forearm',
      nameFa: 'کشش مچ دست و ساعد',
      descriptionFa:
          'دست راست را مستقیم جلو بیاورید، با دست دیگر انگشتان را به سمت عقب بکشید تا خستگی ناشی از تایپ یا نوشتن تخلیه شود.',
      durationSeconds: 30,
      targetArea: 'مچ و ساعد',
      emoji: '✍️',
    ),
    BreakMobilityExercise(
      id: 'desk_chest_expansion',
      nameFa: 'قلاب کردن دست‌ها و باز کردن سینه',
      descriptionFa:
          'دست‌ها را پشت صندلی در هم قلاب کنید، قفسه سینه را بالا بیاورید و چند نفس عمیق بکشید تا خمیدگی ناشی از مطالعه رفع شود.',
      durationSeconds: 30,
      targetArea: 'قفسه سینه و بالاتنه',
      emoji: '🫁',
    ),
  ];

  /// Retrieves a list of desk-friendly stretching exercises from SQLite if available,
  /// or returns the curated safe list.
  Future<List<BreakMobilityExercise>> getDeskBreakExercises({
    int count = 3,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT id, name, instructions, durationSeconds, toolsRequired, category
        FROM ss_exercise
        WHERE (cat_stretching = 1 OR cat_shoulder_and_back = 1 OR category = 'stretching')
          AND noisy = 0
          AND (toolsRequired IS NULL OR toolsRequired = '[]' OR toolsRequired = '')
        LIMIT 10
      ''');

      if (rows.isNotEmpty) {
        final exercises = <BreakMobilityExercise>[];
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString() ?? '';
          final instructions = row['instructions']?.toString() ?? '';
          final dur = (row['durationSeconds'] as num?)?.toInt() ?? 30;

          exercises.add(
            BreakMobilityExercise(
              id: id,
              nameFa: name,
              descriptionFa: instructions.isNotEmpty
                  ? instructions
                  : 'حرکت کششی را آرام و بدون ضربه زدن انجام دهید.',
              durationSeconds: dur > 0 ? dur : 30,
              targetArea: 'رفع گرفتگی عضلانی',
              emoji: '🌿',
            ),
          );
        }

        // Shuffle to keep recommendations fresh across breaks
        exercises.shuffle();
        return exercises.take(count).toList();
      }
    } catch (e) {
      debugPrint('RitmoBreakMobilityEngine: Falling back to curated list: $e');
    }

    final fallback = List<BreakMobilityExercise>.from(_curatedFallbackExercises)
      ..shuffle();
    return fallback.take(count).toList();
  }
}
