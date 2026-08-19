import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_daily_checkin_model.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/muscle_group.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_readiness_service.dart';

/// Body part definition for the soreness selector
class _BodyPartDef {
  const _BodyPartDef(this.code, this.titleFa, this.emoji);
  final String code;
  final String titleFa;
  final String emoji;
}

const _kBodyParts = <_BodyPartDef>[
  _BodyPartDef('CHEST', 'سینه', '🫁'),
  _BodyPartDef('SHOULDER', 'سرشانه', '🎯'),
  _BodyPartDef('BACK', 'پشت', '🪽'),
  _BodyPartDef('BICEPS', 'جلوبازو', '💪'),
  _BodyPartDef('TRICEPS', 'پشت‌بازو', '🦾'),
  _BodyPartDef('CORE', 'شکم', '🎽'),
  _BodyPartDef('QUADS_GLUTES', 'ران و باسن', '🦵'),
  _BodyPartDef('HAMSTRINGS', 'پشت ران', '🦿'),
  _BodyPartDef('CALVES', 'ساق پا', '🏃'),
];

/// Parses sore body parts from checkin note (JSON list stored in note field)
List<String> _parseSoreParts(String? note) {
  if (note == null || note.isEmpty) return [];
  try {
    final decoded = jsonDecode(note);
    if (decoded is Map && decoded.containsKey('soreParts')) {
      return List<String>.from(decoded['soreParts'] as List);
    }
  } catch (e) { debugPrint('[ss] ss_daily_checkin_widget.dart: $e'); }
  return [];
}

/// Encodes sore body parts into note field JSON
String? _encodeSoreParts(Set<String> parts) {
  if (parts.isEmpty) return null;
  return jsonEncode({'soreParts': parts.toList()});
}

class SSDailyCheckinWidget extends StatefulWidget {
  const SSDailyCheckinWidget({
    super.key,
    this.existingCheckin,
    required this.onSaved,
  });

  final SsDailyCheckin? existingCheckin;
  final VoidCallback onSaved;

  @override
  State<SSDailyCheckinWidget> createState() => _SSDailyCheckinWidgetState();
}

class _SSDailyCheckinWidgetState extends State<SSDailyCheckinWidget>
    with SingleTickerProviderStateMixin {
  late int _energy;
  late int _availableMinutes;
  late Set<String> _soreBodyParts;
  bool _isSaving = false;

  /// After submit, we collapse to a summary with undo
  bool _justSubmitted = false;

  /// Stored previous checkin for undo
  SsDailyCheckin? _previousCheckin;

  late AnimationController _collapseController;
  late Animation<double> _collapseAnim;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCheckin;
    _energy = existing?.energy ?? 3;
    _availableMinutes = existing?.availableMinutes ?? 45;
    _soreBodyParts = _parseSoreParts(existing?.note).toSet();

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _collapseAnim = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    RitmoHaptics.confirm();

    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final nowMs = today.millisecondsSinceEpoch;

    // Save previous state for undo
    _previousCheckin = widget.existingCheckin;

    // Compute soreness level from count of sore parts (for backward compat)
    final sorenessLevel = _soreBodyParts.isEmpty
        ? 1
        : (_soreBodyParts.length <= 2 ? 2 : (_soreBodyParts.length <= 4 ? 3 : 4));

    final checkin = SsDailyCheckin(
      dateIso: dateKey,
      energy: _energy,
      soreness: sorenessLevel,
      fatigue: _energy <= 2 ? 4 : (_energy == 3 ? 2 : 1),
      painLevel: 0,
      availableMinutes: _availableMinutes,
      note: _encodeSoreParts(_soreBodyParts),
      createdAt: widget.existingCheckin?.createdAt ?? nowMs,
      updatedAt: nowMs,
    );

    await SSReadinessService.instance.saveDailyCheckin(checkin);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _justSubmitted = true;
      });
      unawaited(_collapseController.forward());

      // If user has sore body parts, offer exercise swap after a short delay
      if (_soreBodyParts.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _showExerciseSwapSuggestion();
        });
      }

      widget.onSaved();
    }
  }

  Future<void> _undo() async {
    RitmoHaptics.tap();
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (_previousCheckin != null) {
      await SSReadinessService.instance.saveDailyCheckin(_previousCheckin!);
    } else {
      // Delete today's checkin
      await SSReadinessService.instance.deleteDailyCheckin(dateKey);
    }

    if (mounted) {
      unawaited(_collapseController.reverse());
      setState(() {
        _justSubmitted = false;
        if (_previousCheckin != null) {
          _energy = _previousCheckin!.energy;
          _availableMinutes = _previousCheckin!.availableMinutes ?? 45;
          _soreBodyParts = _parseSoreParts(_previousCheckin!.note).toSet();
        } else {
          _energy = 3;
          _availableMinutes = 45;
          _soreBodyParts = {};
        }
      });
      widget.onSaved();
    }
  }

  void _toggleBodyPart(String code) {
    RitmoHaptics.selection();
    setState(() {
      if (_soreBodyParts.contains(code)) {
        _soreBodyParts.remove(code);
      } else {
        _soreBodyParts.add(code);
      }
    });
  }

  /// Maps muscle group codes to exercise category patterns for matching
  static const _muscleToCategory = <String, List<String>>{
    'CHEST': ['upper_body', 'chest'],
    'SHOULDER': ['upper_body', 'shoulder_and_back', 'shoulder'],
    'BACK': ['upper_body', 'shoulder_and_back', 'back'],
    'BICEPS': ['upper_body', 'arms', 'biceps'],
    'TRICEPS': ['upper_body', 'arms', 'triceps'],
    'CORE': ['core', 'abs'],
    'QUADS_GLUTES': ['lower_body', 'legs', 'quads', 'glutes'],
    'HAMSTRINGS': ['lower_body', 'legs', 'hamstrings'],
    'CALVES': ['lower_body', 'legs', 'calves'],
  };

  Future<void> _showExerciseSwapSuggestion() async {
    final db = await DatabaseHelper.instance.database;

    // Find today's workout plan
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Get today's prescription
    final prescRows = await db.query(
      'ss_session_prescription',
      where: 'dateIso = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (prescRows.isEmpty) return;

    final presc = prescRows.first;
    final planId = presc['workoutPlanId']?.toString();
    if (planId == null || planId.isEmpty) return;
    final status = presc['status']?.toString() ?? 'PLANNED';
    if (status == 'DONE' || status == 'PARTIAL') return;

    // Get exercises in today's plan
    final crossRefs = await db.rawQuery('''
      SELECT c.id as crossRefId, c.exerciseId, c.orderIndex, c.targetSets, c.targetReps, c.targetWeight,
             e.name, e.category, e.muscleIntensity
      FROM ss_workout_exercise_crossref c
      JOIN ss_exercise e ON e.id = c.exerciseId
      WHERE c.planId = ?
      ORDER BY c.orderIndex ASC
    ''', [planId]);

    if (crossRefs.isEmpty) return;

    // Build set of sore category patterns
    final soreCategories = <String>{};
    for (final part in _soreBodyParts) {
      final cats = _muscleToCategory[part];
      if (cats != null) soreCategories.addAll(cats);
    }

    // Find exercises that target sore muscles
    final conflicting = <Map<String, dynamic>>[];
    for (final ex in crossRefs) {
      final category = ex['category']?.toString().toLowerCase() ?? '';
      final muscleJson = ex['muscleIntensity']?.toString();

      bool conflicts = false;

      // Check category match
      for (final cat in soreCategories) {
        if (category.contains(cat)) {
          conflicts = true;
          break;
        }
      }

      // Check muscleIntensity JSON map
      if (!conflicts && muscleJson != null && muscleJson.isNotEmpty) {
        try {
          final muscleMap = jsonDecode(muscleJson) as Map<String, dynamic>;
          for (final part in _soreBodyParts) {
            final intensity = muscleMap[part] ?? muscleMap[part.toLowerCase()];
            if (intensity != null && (intensity as num) > 0.3) {
              conflicts = true;
              break;
            }
          }
        } catch (e) { debugPrint('[ss] ss_daily_checkin_widget.dart: $e'); }
      }

      if (conflicts) {
        conflicting.add(ex);
      }
    }

    if (conflicting.isEmpty || !mounted) return;

    // Find alternative exercises not targeting sore muscles
    final usedExerciseIds =
        crossRefs.map((e) => e['exerciseId']?.toString()).whereType<String>().toSet();

    // Build alternative query - exercises in same general category but not targeting sore muscles
    final allExercises = await db.query('ss_exercise', limit: 200);
    final alternatives = <Map<String, dynamic>>[];

    for (final altEx in allExercises) {
      if (usedExerciseIds.contains(altEx['id']?.toString())) continue;

      final altCat = altEx['category']?.toString().toLowerCase() ?? '';
      bool altConflicts = false;

      for (final cat in soreCategories) {
        if (altCat.contains(cat)) {
          altConflicts = true;
          break;
        }
      }

      final altMuscleJson = altEx['muscleIntensity']?.toString();
      if (!altConflicts && altMuscleJson != null && altMuscleJson.isNotEmpty) {
        try {
          final muscleMap = jsonDecode(altMuscleJson) as Map<String, dynamic>;
          for (final part in _soreBodyParts) {
            final intensity = muscleMap[part] ?? muscleMap[part.toLowerCase()];
            if (intensity != null && (intensity as num) > 0.3) {
              altConflicts = true;
              break;
            }
          }
        } catch (e) { debugPrint('[ss] ss_daily_checkin_widget.dart: $e'); }
      }

      if (!altConflicts) {
        alternatives.add(altEx);
      }
    }

    if (!mounted) return;

    // Show bottom sheet with swap suggestions
    final sorePartNames = _soreBodyParts
        .map((code) => MuscleGroup.taxonomy[code]?.titleFa ?? code)
        .join('، ');

    unawaited(
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ExerciseSwapSheet(
          conflicting: conflicting,
          alternatives: alternatives,
          sorePartNames: sorePartNames,
          planId: planId,
          onSwapped: () {
            if (mounted) widget.onSaved();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If already submitted in this session, show collapsed view
    if (_justSubmitted) {
      return _buildCollapsedView();
    }

    return _buildExpandedForm();
  }

  Widget _buildCollapsedView() {
    final colors = context.colors;
    final soreNames = _soreBodyParts
        .map((code) {
          final def = _kBodyParts.where((p) => p.code == code).firstOrNull;
          return def != null ? '${def.emoji} ${def.titleFa}' : code;
        })
        .join('، ');

    return AnimatedBuilder(
      animation: _collapseAnim,
      builder: (context, child) => child!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'وضعیت امروز ثبت شد ✓',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'انرژی: ${['خیلی کم', 'کم', 'متوسط', 'خوب', 'عالی'][_energy - 1]} · '
                          '${toPersianDigits('$_availableMinutes')} دقیقه'
                          '${_soreBodyParts.isNotEmpty ? ' · کوفتگی: $soreNames' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.white54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Undo button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _undo,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo_rounded, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'واگرد',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedForm() {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.existingCheckin == null
                      ? 'وضعیت امروزت رو ثبت کن ⚡'
                      : 'وضعیت ثبت‌شدهٔ امروز',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (widget.existingCheckin != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ثبت شد ✓',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. Energy selector
            const Text('سطح انرژی:',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Row(
              children: [1, 2, 3, 4, 5].map((lvl) {
                final selected = _energy == lvl;
                final labels = ['خیلی کم', 'کم', 'متوسط', 'خوب', 'عالی'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      RitmoHaptics.selection();
                      setState(() => _energy = lvl);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[lvl - 1],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 2. Sore Body Parts selector (multi-select chips)
            const Text('کوفتگی عضلانی (عضوهای کوفته رو انتخاب کن):',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kBodyParts.map((part) {
                final selected = _soreBodyParts.contains(part.code);
                return GestureDetector(
                  onTap: () => _toggleBodyPart(part.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                            : const Color(0xFF334155),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(part.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          part.titleFa,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? const Color(0xFFF59E0B) : Colors.white70,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, color: Color(0xFFF59E0B), size: 14),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_soreBodyParts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'تمرینات مرتبط با عضوهای کوفته بررسی و پیشنهاد جایگزین داده می‌شود.',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 3. Available Minutes selector
            const Text('زمان در دسترس امروز:',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            Row(
              children: [15, 30, 45, 60].map((min) {
                final selected = _availableMinutes == min;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      RitmoHaptics.selection();
                      setState(() => _availableMinutes = min);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        toPersianDigits('$min د'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.existingCheckin == null
                            ? 'ثبت وضعیت و تطبیق هوشمند تمرین'
                            : 'به‌روزرسانی وضعیت',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that shows exercises conflicting with sore muscles
/// and lets user approve swaps.
class _ExerciseSwapSheet extends StatefulWidget {
  const _ExerciseSwapSheet({
    required this.conflicting,
    required this.alternatives,
    required this.sorePartNames,
    required this.planId,
    required this.onSwapped,
  });

  final List<Map<String, dynamic>> conflicting;
  final List<Map<String, dynamic>> alternatives;
  final String sorePartNames;
  final String planId;
  final VoidCallback onSwapped;

  @override
  State<_ExerciseSwapSheet> createState() => _ExerciseSwapSheetState();
}

class _ExerciseSwapSheetState extends State<_ExerciseSwapSheet> {
  /// Map of crossRefId -> selected alternative exercise id
  final Map<String, String?> _selectedAlternatives = {};
  bool _isSwapping = false;
  bool _swapDone = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first available alternative for each conflicting exercise
    for (int i = 0; i < widget.conflicting.length; i++) {
      final crossRefId = widget.conflicting[i]['crossRefId']?.toString() ?? '';
      if (widget.alternatives.length > i) {
        _selectedAlternatives[crossRefId] = widget.alternatives[i]['id']?.toString();
      }
    }
  }

  Future<void> _applySwaps() async {
    setState(() => _isSwapping = true);
    RitmoHaptics.confirm();

    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      for (final entry in _selectedAlternatives.entries) {
        final crossRefId = entry.key;
        final newExerciseId = entry.value;
        if (newExerciseId == null || newExerciseId.isEmpty) continue;

        await txn.update(
          'ss_workout_exercise_crossref',
          {'exerciseId': newExerciseId},
          where: 'id = ?',
          whereArgs: [crossRefId],
        );
      }
    });

    if (mounted) {
      setState(() {
        _isSwapping = false;
        _swapDone = true;
      });
      widget.onSwapped();
      // Close after a brief pause
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.85),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            color: Color(0xFFF59E0B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'پیشنهاد جایگزینی حرکات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'با توجه به کوفتگی ${widget.sorePartNames}، حرکات زیر ممکنه فشار اضافه‌ای بیاره. '
                    'می‌خوای جایگزین بشن؟',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF1E293B), height: 1),

            // List of conflicting exercises
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shrinkWrap: true,
                itemCount: widget.conflicting.length,
                itemBuilder: (ctx, i) {
                  final ex = widget.conflicting[i];
                  final crossRefId = ex['crossRefId']?.toString() ?? '';
                  final name = ex['name']?.toString() ?? 'حرکت';
                  final selectedAlt = _selectedAlternatives[crossRefId];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current exercise
                        Row(
                          children: [
                            const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (widget.alternatives.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'جایگزین:',
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.white54),
                          ),
                          const SizedBox(height: 4),
                          // Alternative exercise dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedAlt,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                                hint: const Text(
                                  'انتخاب جایگزین...',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white38),
                                ),
                                items: widget.alternatives.take(15).map((alt) {
                                  final altId = alt['id']?.toString() ?? '';
                                  final altName = alt['name']?.toString() ?? 'حرکت';
                                  return DropdownMenuItem<String>(
                                    value: altId,
                                    child: Text(altName,
                                        style: const TextStyle()),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedAlternatives[crossRefId] = val;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  // Apply swaps
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _isSwapping || _swapDone ? null : _applySwaps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _swapDone
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          _swapDone ? Icons.check_rounded : Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          _swapDone
                              ? 'تغییرات اعمال شد ✓'
                              : 'تأیید و جایگزینی',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Skip
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'فعلاً نه',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),);
  }
}
