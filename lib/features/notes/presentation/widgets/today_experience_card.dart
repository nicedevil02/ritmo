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
    final isDark = context.isDark;
    final exp = _candidate!.experience;
    final note = _candidate!.note;
    final insightsColor = context.modules.insights;

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [insightsColor.withValues(alpha: 0.16), colors.surface]
              : [insightsColor.withValues(alpha: 0.08), colors.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: insightsColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: insightsColor.withValues(alpha: 0.08),
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
                  Text(exp.category.emoji, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: RitmoSpacing.xs),
                  Text(
                    'درس امروز • ${exp.category.labelFa}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: insightsColor,
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
                      color: idx < exp.importance ? insightsColor : colors.textTertiary,
                    );
                  }),
                  const SizedBox(width: RitmoSpacing.xs),
                  InkWell(
                    onTap: _showReasonDialog,
                    borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                    child: Padding(
                      padding: const EdgeInsets.all(RitmoSpacing.xs / 2),
                      child: Icon(CupertinoIcons.question_circle, size: 14, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // Lesson text
          Text(
            '« ${exp.lesson} »',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.45,
                ),
          ),

          if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.xs),
            Text(
              exp.contextText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
            ),
          ],
          const SizedBox(height: RitmoSpacing.md),

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
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  child: AnimatedContainer(
                    duration: RitmoMotion.state,
                    padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: _acknowledged ? colors.success.withValues(alpha: 0.15) : insightsColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _acknowledged ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.lightbulb_fill,
                          size: 14,
                          color: _acknowledged ? colors.success : insightsColor,
                        ),
                        const SizedBox(width: RitmoSpacing.xs),
                        Text(
                          _acknowledged ? 'به خاطر سپردم' : 'به خاطر سپردم',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _acknowledged ? colors.success : insightsColor,
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
                      'مشاهده یادداشت',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(width: RitmoSpacing.xs / 2),
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
