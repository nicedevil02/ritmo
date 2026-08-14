import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_dialog.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
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
  bool _isAcknowledgingPressed = false;

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
    RitmoHapticsPolicy.success();
    await ExperienceRepository.instance.recordAcknowledged(_candidate!.experience.noteId);
    if (mounted) {
      setState(() {
        _acknowledged = true;
      });
    }
  }

  void _showReasonDialog() {
    if (_candidate == null) return;
    final exp = _candidate!.experience;

    RitmoDialog.show(
      context,
      title: 'چرا این درس پیشنهاد شد؟',
      content: 'سیستم بازخوانی هوشمند بر اساس عوامل زیر این درس را برای امروز انتخاب کرده است:\n\n'
          '• ${_candidate!.reasonFa}\n'
          '• تعداد مرورهای قبلی: ${PersianDigits.convert(exp.showCount.toString())} بار\n'
          '• تعداد تاییدها: ${PersianDigits.convert(exp.acknowledgedCount.toString())} بار',
      confirmLabel: 'متوجه شدم',
      cancelLabel: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _candidate == null) return const SizedBox.shrink();

    final colors = context.colors;
    final insightsColor = context.modules.insights;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exp = _candidate!.experience;
    final note = _candidate!.note;

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 18,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: insightsColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Text(exp.category.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      'درس امروز • ${exp.category.labelFa}',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: insightsColor,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  ...List.generate(5, (idx) {
                    return Icon(
                      idx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      size: 12,
                      color: idx < exp.importance ? insightsColor : colors.textTertiary.withValues(alpha: 0.35),
                    );
                  }),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _showReasonDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(CupertinoIcons.question_circle, size: 14, color: colors.textSecondary.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lesson text
          Text(
            '« ${exp.lesson} »',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.w800,
              fontSize: 15,
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
                color: colors.textSecondary.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedScale(
                scale: _isAcknowledgingPressed ? 0.95 : 1.0,
                duration: RitmoMotion.press,
                child: InkWell(
                  onTapDown: (_) => setState(() => _isAcknowledgingPressed = true),
                  onTapCancel: () => setState(() => _isAcknowledgingPressed = false),
                  onTap: () {
                    setState(() => _isAcknowledgingPressed = false);
                    _handleAcknowledge();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: RitmoMotion.state,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _acknowledged
                          ? colors.success.withValues(alpha: isDark ? 0.2 : 0.12)
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _acknowledged
                            ? colors.success.withValues(alpha: 0.4)
                            : colors.primary.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _acknowledged ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.lightbulb_fill,
                          size: 14,
                          color: _acknowledged ? colors.success : colors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _acknowledged ? 'به خاطر سپرده شد' : 'به خاطر سپردم',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _acknowledged ? colors.success : colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مشاهده متن کامل',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_left, size: 12, color: colors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: RitmoMotion.sheet,
        curve: RitmoMotion.enter,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.96 + (0.04 * value),
              child: child,
            ),
          );
        },
        child: cardContent,
      ),
    );
  }
}
