import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/spaced_repetition_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';

class NoteSrsReviewScreen extends StatefulWidget {
  const NoteSrsReviewScreen({super.key});

  @override
  State<NoteSrsReviewScreen> createState() => _NoteSrsReviewScreenState();
}

class _NoteSrsReviewScreenState extends State<NoteSrsReviewScreen> with SingleTickerProviderStateMixin {
  List<Note> _dueNotes = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  Experience? _currentExp;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: RitmoMotion.sheet,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: RitmoMotion.enter),
    );
    _loadDueReviews();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    RitmoHapticsPolicy.selection();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  Future<void> _loadDueReviews() async {
    setState(() => _isLoading = true);
    final notes = await SpacedRepetitionEngine.instance.listDueReviews();
    if (mounted) {
      setState(() {
        _dueNotes = notes;
        _currentIndex = 0;
        _isFront = true;
        _isLoading = false;
      });
      _flipController.reset();
      if (_dueNotes.isNotEmpty) {
        await _loadExperienceMeta(_dueNotes.first.id);
      }
    }
  }

  Future<void> _loadExperienceMeta(String noteId) async {
    final exp = await ExperienceRepository.instance.getByNoteId(noteId);
    if (mounted) {
      setState(() {
        _currentExp = exp;
      });
    }
  }

  Future<void> _submitFeedback(ReviewFeedback feedback) async {
    if (_dueNotes.isEmpty || _currentIndex >= _dueNotes.length) return;

    if (feedback == ReviewFeedback.easy) {
      RitmoHapticsPolicy.success();
    } else if (feedback == ReviewFeedback.good) {
      RitmoHapticsPolicy.tap();
    } else {
      RitmoHapticsPolicy.selection();
    }

    final currentNote = _dueNotes[_currentIndex];
    await SpacedRepetitionEngine.instance.scheduleNextReview(currentNote.id, feedback);

    if (mounted) {
      if (_currentIndex + 1 < _dueNotes.length) {
        setState(() {
          _currentIndex++;
          _isFront = true;
          _currentExp = null;
        });
        _flipController.reset();
        await _loadExperienceMeta(_dueNotes[_currentIndex].id);
      } else {
        setState(() {
          _currentIndex++;
        });
        RitmoToast.show(context, 'مرور تمامی موارد امروز به پایان رسید! 🎉');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = !_isLoading && (_dueNotes.isEmpty || _currentIndex >= _dueNotes.length);
    final progress = _dueNotes.isNotEmpty ? (_currentIndex / _dueNotes.length).clamp(0.0, 1.0) : 1.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Luxury App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              RitmoHapticsPolicy.tap();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.surfaceSunken,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colors.border,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.arrow_right,
                                size: 18,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'مرور فاصله‌دار هوشمند',
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            ),
                        ),
                      ],
                    ),
                    if (!_isLoading && _dueNotes.isNotEmpty && _currentIndex < _dueNotes.length)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${PersianDigits.convert((_currentIndex + 1).toString())} از ${PersianDigits.convert(_dueNotes.length.toString())}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? colors.accent : colors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Progress Bar
              if (!_isLoading && _dueNotes.isNotEmpty && !isDone)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colors.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),

              // Main Body
              Expanded(
                child: _isLoading
                    ? const RitmoShimmerList(count: 3)
                    : isDone
                        ? _buildCompletionView(context, colors, isDark)
                        : _buildReviewCardView(context, colors, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, RitmoColors colors, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(CupertinoIcons.sparkles, size: 52, color: colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'همه موارد امروز مرور شدند!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تمام یادداشت‌ها و درس‌های معوقه امروز با موفقیت مرور و در تقویم حافظه ثبت شدند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () {
                RitmoHapticsPolicy.tap();
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: colors.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'بازگشت به دفترچه',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCardView(BuildContext context, RitmoColors colors, bool isDark) {
    final note = _dueNotes[_currentIndex];
    final isExp = note.kind == NoteKind.experience || _currentExp != null;
    final style = NoteUiHelper.getKindStyle(context, isExp ? NoteKind.experience : note.kind);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3D Flip Card
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (ctx, child) {
                  final angle = _flipAnimation.value * pi;
                  final isShowingFront = angle <= pi / 2;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: isShowingFront
                        ? _buildCardFront(context, note, style, isDark, colors)
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _buildCardBack(context, note, style, isDark, colors),
                          ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4 Tactile Feedback Buttons
          Text(
            'میزان تسلط و به خاطرسپاری:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'فراموش شد',
                  subtext: 'مرحله ۱',
                  icon: CupertinoIcons.clear,
                  color: colors.error,
                  onTap: () => _submitFeedback(ReviewFeedback.forgotten),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'سخت بود',
                  subtext: 'تکرار',
                  icon: CupertinoIcons.exclamationmark_triangle,
                  color: colors.warning,
                  onTap: () => _submitFeedback(ReviewFeedback.hard),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'خوب بود',
                  subtext: '+۱ مرحله',
                  icon: CupertinoIcons.hand_thumbsup,
                  color: colors.success,
                  onTap: () => _submitFeedback(ReviewFeedback.good),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'آسان بود',
                  subtext: '+۲ مرحله',
                  icon: CupertinoIcons.bolt_fill,
                  color: colors.primary,
                  onTap: () => _submitFeedback(ReviewFeedback.easy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(BuildContext context, Note note, NoteKindStyle style, bool isDark, RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: style.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: style.accentColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(style.icon, size: 13, color: style.accentColor),
                    const SizedBox(width: 5),
                    Text(
                      _currentExp != null ? _currentExp!.category.labelFa : style.labelFa,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: style.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'مرحله مرور: ${PersianDigits.convert(note.reviewStage.toString())}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Key Lesson or Title
          Center(
            child: Text(
              '« ${_currentExp?.lesson ?? note.title ?? note.body} »',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const Spacer(),

          // Flip prompt
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.arrow_2_circlepath, size: 14, color: style.accentColor),
                const SizedBox(width: 6),
                Text(
                  'برای مشاهده جزئیات و پاسخ، کارت را لمس کنید',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: style.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, Note note, NoteKindStyle style, bool isDark, RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جزئیات و متن کامل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: style.accentColor,
                ),
              ),
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                  );
                  await _loadDueReviews();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 12, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'ویرایش',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                note.body,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textPrimary,
                  height: 1.65,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.arrow_2_circlepath, size: 13, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'لمس کارت برای بازگشت به روی کارت',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SrsFeedbackButton extends StatefulWidget {
  final String label;
  final String subtext;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SrsFeedbackButton({
    required this.label,
    required this.subtext,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SrsFeedbackButton> createState() => _SrsFeedbackButtonState();
}

class _SrsFeedbackButtonState extends State<_SrsFeedbackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScale(
      scale: _isPressed ? 0.94 : 1.0,
      duration: RitmoMotion.press,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.subtext,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: widget.color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
