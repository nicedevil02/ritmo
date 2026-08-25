import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_kind_picker_sheet.dart';
import '../components/components.dart';

/// Screen 6: "آنبوردینگ ورزشی ریتمو" (Section 5.6, AC-01 & S2-T5).
/// Fast question-based onboarding with fixed anchor commitment support.
class MvOnboardingScreen extends StatefulWidget {
  final Future<void> Function(MvUserProfile profile) onComplete;
  final Future<void> Function(MvUserProfile profile, List<MvCommitment> commitments)? onCompleteWithCommitments;
  final MvKindUseCase? kindUseCase;
  final MvCommitmentUseCase? commitmentUseCase;
  final List<MvMovementKind>? initialKinds;

  const MvOnboardingScreen({
    super.key,
    required this.onComplete,
    this.onCompleteWithCommitments,
    this.kindUseCase,
    this.commitmentUseCase,
    this.initialKinds,
  });

  @override
  State<MvOnboardingScreen> createState() => _MvOnboardingScreenState();
}

class _MvOnboardingScreenState extends State<MvOnboardingScreen> {
  static const _profileEngine = ProfileEngine();
  late final MvKindUseCase _kindUseCase;
  late final MvCommitmentUseCase _commitmentUseCase;

  int _daysPerWeek = 3;
  String _sessionDuration = 'medium'; // short (15m), medium (30m), long (45m)
  String _trainingLocation = 'home'; // home, gym, outdoor
  final List<MvCommitment> _commitments = [];
  List<MvMovementKind> _allKinds = [];
  bool? _hasFixedAnchor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    _commitmentUseCase = widget.commitmentUseCase ?? MvCommitmentUseCase();
    if (widget.initialKinds != null && widget.initialKinds!.isNotEmpty) {
      _allKinds = widget.initialKinds!;
    } else {
      _loadKinds();
    }
  }

  Future<void> _loadKinds() async {
    try {
      final kinds = await _kindUseCase.getAllKinds();
      if (mounted) {
        setState(() => _allKinds = kinds);
      }
    } catch (_) {}
  }

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);
    final decision = _profileEngine.createQuickProfile(
      daysPerWeek: _daysPerWeek,
      sessionDuration: _sessionDuration,
      trainingLocation: _trainingLocation,
    );

    // ذخیرهٔ تعهدها در دیتابیس
    for (final c in _commitments) {
      await _commitmentUseCase.saveCommitment(c);
    }

    if (widget.onCompleteWithCommitments != null) {
      await widget.onCompleteWithCommitments!(decision.value, _commitments);
    } else {
      await widget.onComplete(decision.value);
    }
  }

  Future<void> _openAddAnchorFlow() async {
    final pickedKind = await MvKindPickerSheet.show(
      context: context,
      useCase: _kindUseCase,
      initialKinds: widget.initialKinds ?? (_allKinds.isNotEmpty ? _allKinds : null),
    );

    if (pickedKind == null || !mounted) return;

    // باز کردن شیت تنظیم تعهد (روز، ساعت، مدت)
    await _showCommitmentConfigSheet(pickedKind);
  }

  Future<void> _showCommitmentConfigSheet(MvMovementKind kind) async {
    int selectedDay = 5; // پنجشنبه پیش‌فرض
    TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);
    int selectedDuration = 60;
    final venueController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ritmoColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.metrics.radiusSheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = context.ritmoColors;
            final metrics = context.metrics;
            final textTheme = Theme.of(context).textTheme;

            return Padding(
              padding: EdgeInsets.only(
                left: metrics.spaceLg,
                right: metrics.spaceLg,
                top: metrics.spaceLg,
                bottom: MediaQuery.of(context).viewInsets.bottom + metrics.spaceLg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تنظیم ورزش ثابت: ${kind.titleFa} ${kind.emoji}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: metrics.spaceMd),

                    // روز هفته
                    Text('روز هفته', style: textTheme.labelMedium),
                    SizedBox(height: metrics.spaceXs),
                    Wrap(
                      spacing: metrics.spaceSm,
                      runSpacing: metrics.spaceSm,
                      children: List.generate(7, (idx) {
                        final isSel = selectedDay == idx;
                        final name = MvCalendar.persianWeekdayName(idx);
                        return ChoiceChip(
                          label: Text(name),
                          selected: isSel,
                          onSelected: (_) => setSheetState(() => selectedDay = idx),
                        );
                      }),
                    ),
                    SizedBox(height: metrics.spaceMd),

                    // ساعت شروع
                    Text('ساعت شروع', style: textTheme.labelMedium),
                    SizedBox(height: metrics.spaceXs),
                    InkWell(
                      key: const ValueKey('onboarding_time_picker_btn'),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheetState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(metrics.spaceSm),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(metrics.radiusField),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          '${toPersianDigits(selectedTime.hour.toString().padLeft(2, '0'))}:${toPersianDigits(selectedTime.minute.toString().padLeft(2, '0'))}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    SizedBox(height: metrics.spaceMd),

                    // مدت زمان
                    Text('مدت زمان (دقیقه)', style: textTheme.labelMedium),
                    SizedBox(height: metrics.spaceXs),
                    Wrap(
                      spacing: metrics.spaceSm,
                      runSpacing: metrics.spaceSm,
                      children: [45, 60, 90, 120].map((dur) {
                        return ChoiceChip(
                          label: Text('${toPersianDigits(dur.toString())} دقیقه'),
                          selected: selectedDuration == dur,
                          onSelected: (_) => setSheetState(() => selectedDuration = dur),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: metrics.spaceLg),

                    // دکمه تایید
                    MvPrimaryAction(
                      key: const ValueKey('confirm_anchor_commitment_btn'),
                      label: 'تأیید و افزودن',
                      icon: Icons.check_rounded,
                      onPressed: () {
                        final timeStr =
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                        final commitment = MvCommitment(
                          kindCode: kind.code,
                          titleFa: kind.titleFa,
                          dayOfWeekSat0: selectedDay,
                          startTime: timeStr,
                          durationMinutes: selectedDuration,
                          venueNote: venueController.text.trim().isNotEmpty
                              ? venueController.text.trim()
                              : null,
                          recurrence: CommitmentRecurrence.weekly,
                          isActive: true,
                        );
                        setState(() {
                          _commitments.add(commitment);
                          _hasFixedAnchor = true;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(metrics.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'برنامهٔ ورزشی اختصاصی تو',
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: metrics.spaceXs),
              Text(
                'با پاسخ به چند سؤال کوتاه، برنامهٔ هفته‌ات را بساز.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: metrics.spaceXl),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question 1: Days per week
                      _buildQuestionTitle(
                        '۱. چند روز در هفته می‌خواهی ورزش کنی؟',
                      ),
                      SizedBox(height: metrics.spaceSm),
                      Row(
                        children: [2, 3, 4, 5].map((d) {
                          final isSel = _daysPerWeek == d;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: metrics.spaceXs,
                              ),
                              child: ChoiceChip(
                                label: Text('${toPersianDigits(d.toString())} روز'),
                                selected: isSel,
                                onSelected: (_) =>
                                    setState(() => _daysPerWeek = d),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: metrics.spaceXl),

                      // Question 2: Session duration
                      _buildQuestionTitle('۲. چقدر زمان داری در هر جلسه؟'),
                      SizedBox(height: metrics.spaceSm),
                      Wrap(
                        spacing: metrics.spaceSm,
                        runSpacing: metrics.spaceSm,
                        children: [
                          _buildChoice(
                            label: '۱۵ دقیقه (کوتاه و سریع)',
                            emoji: '⚡',
                            isSelected: _sessionDuration == 'short',
                            onTap: () =>
                                setState(() => _sessionDuration = 'short'),
                          ),
                          _buildChoice(
                            label: '۳۰ دقیقه (متعادل و ایده‌آل)',
                            emoji: '⏱️',
                            isSelected: _sessionDuration == 'medium',
                            onTap: () =>
                                setState(() => _sessionDuration = 'medium'),
                          ),
                          _buildChoice(
                            label: '۴۵ دقیقه یا بیشتر',
                            emoji: '🔥',
                            isSelected: _sessionDuration == 'long',
                            onTap: () =>
                                setState(() => _sessionDuration = 'long'),
                          ),
                        ],
                      ),
                      SizedBox(height: metrics.spaceXl),

                      // Question 3: Location
                      _buildQuestionTitle('۳. محیط تمرینت کجاست؟'),
                      SizedBox(height: metrics.spaceSm),
                      Wrap(
                        spacing: metrics.spaceSm,
                        runSpacing: metrics.spaceSm,
                        children: [
                          _buildChoice(
                            label: 'خانه (بدون وسیله)',
                            emoji: '🏠',
                            isSelected: _trainingLocation == 'home',
                            onTap: () =>
                                setState(() => _trainingLocation = 'home'),
                          ),
                          _buildChoice(
                            label: 'باشگاه ورزشی',
                            emoji: '🏋️',
                            isSelected: _trainingLocation == 'gym',
                            onTap: () =>
                                setState(() => _trainingLocation = 'gym'),
                          ),
                          _buildChoice(
                            label: 'فضای باز / پارک',
                            emoji: '🌳',
                            isSelected: _trainingLocation == 'outdoor',
                            onTap: () =>
                                setState(() => _trainingLocation = 'outdoor'),
                          ),
                        ],
                      ),
                      SizedBox(height: metrics.spaceXl),

                      // Question 4: Anchor Commitment (S2-T5)
                      _buildQuestionTitle(
                        '۴. ورزش ثابتی داری که هفته‌ای انجام بدهی؟',
                        key: const ValueKey('mv_onboarding_anchor_title'),
                      ),
                      SizedBox(height: metrics.spaceXs),
                      Text(
                        'مثل فوتسال پنجشنبه‌ها یا استخر جمعه‌ها (اختیاری)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: metrics.spaceSm),

                      if (_commitments.isEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoice(
                                key: const ValueKey('onboarding_add_anchor_btn'),
                                label: 'بله، اضافه کنم',
                                emoji: '⚽',
                                isSelected: _hasFixedAnchor == true,
                                onTap: _openAddAnchorFlow,
                              ),
                            ),
                            SizedBox(width: metrics.spaceSm),
                            Expanded(
                              child: _buildChoice(
                                key: const ValueKey('onboarding_skip_anchor_btn'),
                                label: 'فعلاً نه',
                                emoji: '⏭️',
                                isSelected: _hasFixedAnchor == false,
                                onTap: () => setState(() => _hasFixedAnchor = false),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Render commitment list
                        ..._commitments.map((c) {
                          return Container(
                            margin: EdgeInsets.only(bottom: metrics.spaceSm),
                            padding: EdgeInsets.symmetric(
                              horizontal: metrics.spaceMd,
                              vertical: metrics.spaceSm,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(metrics.radiusCard),
                              border: Border.all(color: colors.primary),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFD4A843)),
                                SizedBox(width: metrics.spaceSm),
                                Expanded(
                                  child: Text(
                                    '${c.persianWeekdayName}: ${c.titleFa ?? c.kindCode} (ساعت ${toPersianDigits(c.startTime)} — ${toPersianDigits(c.durationMinutes.toString())} دقیقه)',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _commitments.remove(c);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_commitments.length < 3) ...[
                          OutlinedButton.icon(
                            key: const ValueKey('onboarding_add_another_anchor_btn'),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('افزودن ورزش ثابت دیگر'),
                            onPressed: _openAddAnchorFlow,
                          ),
                        ],
                      ],
                      SizedBox(height: metrics.spaceXl),
                    ],
                  ),
                ),
              ),

              // CTA
              MvPrimaryAction(
                key: const ValueKey('onboarding_submit_action'),
                label: 'شروع برنامه و ورود به ریتمو',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isLoading,
                onPressed: _handleFinish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTitle(String title, {Key? key}) {
    return Text(
      title,
      key: key,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.ritmoColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildChoice({
    Key? key,
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.spaceMd,
            vertical: metrics.spaceSm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surface,
            borderRadius: BorderRadius.circular(metrics.radiusCard),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              SizedBox(width: metrics.spaceSm),
              Flexible(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected ? colors.primary : colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
