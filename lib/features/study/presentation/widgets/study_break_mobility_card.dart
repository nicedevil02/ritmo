import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_break_mobility_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'study_break_mobility_player_sheet.dart';

/// Interactive Neumorphic card shown inside study break sheets,
/// proposing gentle 2-minute desk stretches to reduce sedentary fatigue.
class StudyBreakMobilityCard extends StatefulWidget {
  const StudyBreakMobilityCard({super.key});

  @override
  State<StudyBreakMobilityCard> createState() => _StudyBreakMobilityCardState();
}

class _StudyBreakMobilityCardState extends State<StudyBreakMobilityCard> {
  List<BreakMobilityExercise> _exercises = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises =
          await const RitmoBreakMobilityEngine().getDeskBreakExercises(count: 3);
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startStretching(BuildContext context) {
    if (_exercises.isEmpty) return;
    RitmoHapticsPolicy.tap();
    StudyBreakMobilityPlayerSheet.show(
      context,
      exercises: _exercises,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          RitmoCardHeader(
            title: 'کشش و رفع خستگی مطالعه',
            subtitle: '۲ دقیقه آزادسازی گردن و ستون فقرات',
            icon: CupertinoIcons.sparkles,
            iconColor: Colors.teal,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'استراحت پومودورو ☕',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Inset Preview Box
          RitmoNeuSurface(
            sunken: true,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CupertinoActivityIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حرکات پیشنهادی این استراحت:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _exercises.map((ex) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '${ex.emoji} ${ex.nameFa}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // 3. Tactile 3D Action Button
          RitmoNeuButton(
            onTap: () => _startStretching(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.play_arrow_solid,
                    size: 14,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'شروع کشش ۲ دقیقه‌ای 🌿',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
