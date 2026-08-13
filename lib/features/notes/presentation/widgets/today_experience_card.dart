import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/resurfacing_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';

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

  void _showReasonDialog() {
    if (_candidate == null) return;
    final colors = context.colors;
    final exp = _candidate!.experience;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'چرا این درس پیشنهاد شد؟',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سیستم بازخوانی هوشمند بر اساس عوامل زیر این درس را برای امروز انتخاب کرده است:',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${_candidate!.reasonFa}', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('• تعداد مرورهای قبلی: ${PersianDigits.convert(exp.showCount.toString())} بار', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('• تعداد تاییدها: ${PersianDigits.convert(exp.acknowledgedCount.toString())} بار', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متوجه شدم', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_candidate == null) return const SizedBox.shrink();

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exp = _candidate!.experience;
    final note = _candidate!.note;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2B2006), colors.card]
                : [const Color(0xFFFFFBEB), colors.card],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(RitmoRadius.hero),
          border: Border.all(color: const Color(0xFFE5A00D).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE5A00D).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Emoji + Category + Stars + Why Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(exp.category.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'درس امروز • ${exp.category.labelFa}',
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE5A00D),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ...List.generate(5, (idx) {
                      return Icon(
                        idx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                        size: 11,
                        color: idx < exp.importance ? Colors.amber : colors.textTertiary,
                      );
                    }),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _showReasonDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(CupertinoIcons.question_circle, size: 14, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lesson text
            Text(
              '« ${exp.lesson} »',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                height: 1.45,
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
                  height: 1.35,
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _acknowledged ? Colors.green.withValues(alpha: 0.15) : const Color(0xFFE5A00D).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _acknowledged ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.lightbulb_fill,
                          size: 14,
                          color: _acknowledged ? Colors.green : const Color(0xFFE5A00D),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _acknowledged ? 'به خاطر سپردم ✓' : '💡 به خاطر سپردم',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _acknowledged ? Colors.green : const Color(0xFFE5A00D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                    );
                  },
                  icon: Text(
                    'مشاهده یادداشت',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                  label: Icon(CupertinoIcons.chevron_left, size: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
