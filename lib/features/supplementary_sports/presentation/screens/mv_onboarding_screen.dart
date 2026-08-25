import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Screen 6: "آنبوردینگ ورزشی ریتمو" (Section 5.6 & AC-01).
/// 20-second 3-question onboarding delivering a working plan on day 1.
class MvOnboardingScreen extends StatefulWidget {
  final Future<void> Function(MvUserProfile profile) onComplete;

  const MvOnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<MvOnboardingScreen> createState() => _MvOnboardingScreenState();
}

class _MvOnboardingScreenState extends State<MvOnboardingScreen> {
  static const _profileEngine = ProfileEngine();
  int _daysPerWeek = 3;
  String _sessionDuration = 'medium'; // short (15m), medium (30m), long (45m)
  String _trainingLocation = 'home'; // home, gym, outdoor
  bool _isLoading = false;

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);
    final decision = _profileEngine.createQuickProfile(
      daysPerWeek: _daysPerWeek,
      sessionDuration: _sessionDuration,
      trainingLocation: _trainingLocation,
    );

    await widget.onComplete(decision.value);
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
                'تنها با پاسخ به ۳ سؤال کوتاه، برنامهٔ هفته‌ات را بساز.',
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
                      _buildQuestionTitle('۱. چند روز در هفته می‌خواهی ورزش کنی؟'),
                      SizedBox(height: metrics.spaceSm),
                      Row(
                        children: [2, 3, 4, 5].map((d) {
                          final isSel = _daysPerWeek == d;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: metrics.spaceXs),
                              child: ChoiceChip(
                                label: Text('$d روز'),
                                selected: isSel,
                                onSelected: (_) => setState(() => _daysPerWeek = d),
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
                            onTap: () => setState(() => _sessionDuration = 'short'),
                          ),
                          _buildChoice(
                            label: '۳۰ دقیقه (متعادل و ایده‌آل)',
                            emoji: '⏱️',
                            isSelected: _sessionDuration == 'medium',
                            onTap: () => setState(() => _sessionDuration = 'medium'),
                          ),
                          _buildChoice(
                            label: '۴۵ دقیقه یا بیشتر',
                            emoji: '🔥',
                            isSelected: _sessionDuration == 'long',
                            onTap: () => setState(() => _sessionDuration = 'long'),
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
                            onTap: () => setState(() => _trainingLocation = 'home'),
                          ),
                          _buildChoice(
                            label: 'باشگاه ورزشی',
                            emoji: '🏋️',
                            isSelected: _trainingLocation == 'gym',
                            onTap: () => setState(() => _trainingLocation = 'gym'),
                          ),
                          _buildChoice(
                            label: 'فضای باز / پارک',
                            emoji: '🌳',
                            isSelected: _trainingLocation == 'outdoor',
                            onTap: () => setState(() => _trainingLocation = 'outdoor'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // CTA
              MvPrimaryAction(
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

  Widget _buildQuestionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.ritmoColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildChoice({
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: metrics.spaceMd, vertical: metrics.spaceSm),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.surface,
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
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
