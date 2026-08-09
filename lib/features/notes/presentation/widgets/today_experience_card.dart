import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/resurfacing_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/notebook_screen.dart';

class TodayExperienceCard extends StatefulWidget {
  final String? activeCategory;

  const TodayExperienceCard({
    super.key,
    this.activeCategory,
  });

  @override
  State<TodayExperienceCard> createState() => _TodayExperienceCardState();
}

class _TodayExperienceCardState extends State<TodayExperienceCard> {
  ResurfacingCandidate? _candidate;
  bool _isLoading = true;
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    _loadCandidate();
  }

  Future<void> _loadCandidate() async {
    final candidate = await ResurfacingEngine.instance.pickTodayExperienceCandidate(
      activeCategory: widget.activeCategory,
    );
    if (mounted) {
      setState(() {
        _candidate = candidate;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAcknowledge() async {
    if (_candidate == null || _acknowledged) return;
    RitmoHaptics.success();
    await ExperienceRepository.instance.recordAcknowledged(_candidate!.experience.noteId);
    if (mounted) {
      setState(() {
        _acknowledged = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_candidate == null) return const SizedBox.shrink();

    final colors = context.colors;
    final exp = _candidate!.experience;
    final note = _candidate!.note;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Emoji + Category + Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(exp.category.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'تجربه زندگی • ${exp.category.labelFa}',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      size: 11,
                      color: idx < exp.importance ? Colors.amber : colors.textTertiary,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lesson text
            Text(
              exp.lesson,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),

            if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                exp.contextText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _handleAcknowledge,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _acknowledged ? Colors.green.withValues(alpha: 0.15) : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _acknowledged ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.lightbulb_fill,
                          size: 14,
                          color: _acknowledged ? Colors.green : colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _acknowledged ? 'متوجه شدم ✓' : '💡 متوجه شدم',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _acknowledged ? Colors.green : colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotebookScreen()),
                    );
                  },
                  child: Text(
                    'مشاهده در دفترچه ←',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
