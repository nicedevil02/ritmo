import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Screen 5: "تنظیمات ورزش و حرکت" (Section 5.5).
/// Single source of truth settings for sports, equipment, apartment mode, and cycle consent.
class MvSettingsScreen extends StatefulWidget {
  final MvUserProfile initialProfile;
  final ValueChanged<MvUserProfile> onProfileSaved;
  final VoidCallback? onRegenerateProgram;

  const MvSettingsScreen({
    super.key,
    required this.initialProfile,
    required this.onProfileSaved,
    this.onRegenerateProgram,
  });

  @override
  State<MvSettingsScreen> createState() => _MvSettingsScreenState();
}

class _MvSettingsScreenState extends State<MvSettingsScreen> {
  late int _daysPerWeek;
  late String _duration;
  late MvIntensityTier _intensity;
  late bool _apartmentMode;
  late bool _voiceEnabled;
  late bool _cycleConsent;
  late List<int> _trainingDays;

  final List<String> _durations = const ['short', 'medium', 'long'];
  final List<MvIntensityTier> _intensities = MvIntensityTier.values;

  @override
  void initState() {
    super.initState();
    _daysPerWeek = widget.initialProfile.daysPerWeek;
    _duration = widget.initialProfile.sessionDuration;
    _intensity = widget.initialProfile.defaultIntensity;
    _apartmentMode = widget.initialProfile.neighborFriendly;
    _voiceEnabled = widget.initialProfile.voiceCuesEnabled;
    _cycleConsent = widget.initialProfile.cycleConsentGranted;
    _trainingDays = List.from(widget.initialProfile.trainingDays);
  }

  void _saveChanges() {
    final updated = widget.initialProfile.copyWith(
      daysPerWeek: _daysPerWeek,
      sessionDuration: _duration,
      defaultIntensity: _intensity,
      neighborFriendly: _apartmentMode,
      voiceCuesEnabled: _voiceEnabled,
      cycleConsentGranted: _cycleConsent,
      trainingDays: _trainingDays,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onProfileSaved(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات ورزشی'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: Text(
              'ذخیره',
              style: textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(metrics.spaceLg),
        children: [
          // 1. Program & Goal
          _buildSectionHeader('برنامه و اهداف'),
          _buildCard(
            children: [
              Text('تعداد روزهای تمرین در هفته:', style: textTheme.bodyMedium),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                children: [1, 2, 3, 4, 5, 6, 7].map((d) {
                  return MvChip(
                    label: '$d روز',
                    isSelected: _daysPerWeek == d,
                    onTap: () => setState(() => _daysPerWeek = d),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              Text('مدت هر جلسه:', style: textTheme.bodyMedium),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                children: _durations.map((dur) {
                  final label = dur == 'short' ? 'کوتاه (۱۵ دقیقه)' : dur == 'medium' ? 'متوسط (۳۰ دقیقه)' : 'بلند (۴۵+ دقیقه)';
                  return MvChip(
                    label: label,
                    isSelected: _duration == dur,
                    onTap: () => setState(() => _duration = dur),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              Text('شدت پیش‌فرض:', style: textTheme.bodyMedium),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                children: _intensities.map((tier) {
                  return MvChip(
                    label: tier.titleFa,
                    isSelected: _intensity == tier,
                    onTap: () => setState(() => _intensity = tier),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 2. Apartment Mode & Equipment (N-04)
          _buildSectionHeader('محیط و تجهیزات'),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text('حالت همسایه‌پسند (آپارتمانی)', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('حذف خودکار تمام حرکات پرشی و پرصدا', style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                value: _apartmentMode,
                onChanged: (v) => setState(() => _apartmentMode = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 3. Audio & Voice cues
          _buildSectionHeader('راهنمای صوتی و انیمیشن'),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text('راهنمای صوتی مربی', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('پخش پیام‌های شروع، استراحت و شمارش معکوس', style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                value: _voiceEnabled,
                onChanged: (v) => setState(() => _voiceEnabled = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 4. Privacy & Menstrual Cycle Consent (AC-12, Rule 35)
          _buildSectionHeader('حریم خصوصی و داده‌های فیزیولوژیک'),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text('تطبیق شدت با چرخهٔ فیزیولوژیک', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('پیشنهاد روزهای سبک در فاز استراحت چرخه (کاملاً آفلاین و با رضایت کاربر)', style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                value: _cycleConsent,
                onChanged: (v) => setState(() => _cycleConsent = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 5. Advanced Actions
          if (widget.onRegenerateProgram != null) ...[
            _buildSectionHeader('پیشرفته'),
            _buildCard(
              children: [
                ListTile(
                  leading: Icon(Icons.refresh_rounded, color: colors.primary),
                  title: Text('بازسازی برنامهٔ هفتگی', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('برنامهٔ روزها را بازسازی می‌کند بدون اینکه سوابق ورزشی قبلی حذف شود.', style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                  onTap: () {
                    widget.onRegenerateProgram?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.metrics.spaceSm, right: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.ritmoColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(metrics.radiusCard),
      child: Container(
        padding: EdgeInsets.all(metrics.spaceMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
