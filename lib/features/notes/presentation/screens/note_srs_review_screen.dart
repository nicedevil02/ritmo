import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/spaced_repetition_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';

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
      duration: const Duration(milliseconds: 380),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _loadDueReviews();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    RitmoHaptics.selection();
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
      RitmoHaptics.success();
    } else if (feedback == ReviewFeedback.good) {
      RitmoHaptics.confirm();
    } else {
      RitmoHaptics.selection();
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
    final isDone = !_isLoading && (_dueNotes.isEmpty || _currentIndex >= _dueNotes.length);
    final progress = _dueNotes.isNotEmpty ? (_currentIndex / _dueNotes.length).clamp(0.0, 1.0) : 1.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'مرور فاصله‌دار یادگیری و حکمت‌ها 🧠',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 3,
            ),
          ),
          actions: [
            if (!_isLoading && _dueNotes.isNotEmpty && _currentIndex < _dueNotes.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  '${PersianDigits.convert((_currentIndex + 1).toString())} از ${PersianDigits.convert(_dueNotes.length.toString())}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : isDone
                ? _buildCompletionView(context)
                : _buildReviewCardView(context),
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.sparkles, size: 56, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'همه موارد امروز مرور شدند! 🌱',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تمام یادداشت‌ها و درس‌های معوقه امروز با موفقیت مرور و در تقویم حافظه ثبت شدند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.checkmark_alt, size: 18),
              label: const Text('بازگشت به دفترچه', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCardView(BuildContext context) {
    final note = _dueNotes[_currentIndex];
    final isExp = note.kind == NoteKind.experience || _currentExp != null;
    final style = NoteUiHelper.getKindStyle(context, isExp ? NoteKind.experience : note.kind);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                      ..setEntry(3, 2, 0.001) // Perspective effect
                      ..rotateY(angle),
                    child: isShowingFront
                        ? _buildCardFront(context, note, style)
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _buildCardBack(context, note, style),
                          ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4 Tactile Feedback Buttons
          Text(
            'میزان تسلط و به خاطرسپاری:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'فراموش شد',
                  subtext: 'مرحله ۱',
                  emoji: '❌',
                  color: Colors.redAccent,
                  onTap: () => _submitFeedback(ReviewFeedback.forgotten),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'سخت بود',
                  subtext: 'تکرار',
                  emoji: '⚠️',
                  color: Colors.orange,
                  onTap: () => _submitFeedback(ReviewFeedback.hard),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'خوب بود',
                  subtext: '+۱ مرحله',
                  emoji: '👍',
                  color: Colors.lightGreen,
                  onTap: () => _submitFeedback(ReviewFeedback.good),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SrsFeedbackButton(
                  label: 'آسان بود',
                  subtext: '+۲ مرحله',
                  emoji: '⚡',
                  color: const Color(0xFF10B981),
                  onTap: () => _submitFeedback(ReviewFeedback.easy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(BuildContext context, Note note, NoteKindStyle style) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: style.bgTint,
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: style.accentColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: style.accentColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  color: style.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(style.icon, size: 14, color: style.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      _currentExp != null ? '💡 ${_currentExp!.category.labelFa}' : style.labelFa,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
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
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
              ),
            ],
          ),
          const Spacer(),

          // Key Lesson or Title
          Center(
            child: Column(
              children: [
                Text(
                  '« ${_currentExp?.lesson ?? note.title ?? note.body} »',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
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
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
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

  Widget _buildCardBack(BuildContext context, Note note, NoteKindStyle style) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: style.accentColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: style.accentColor,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                  );
                  await _loadDueReviews();
                },
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('ویرایش', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                note.body,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  color: colors.textPrimary,
                  height: 1.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.arrow_2_circlepath, size: 13, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'لمس کارت برای بازگشت به روی کارت',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10,
                    color: colors.textSecondary,
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
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _SrsFeedbackButton({
    required this.label,
    required this.subtext,
    required this.emoji,
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
    return AnimatedScale(
      scale: _isPressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
                Text(
                  widget.subtext,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
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
