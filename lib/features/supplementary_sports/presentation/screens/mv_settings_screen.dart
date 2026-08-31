import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import 'mv_commitments_screen.dart';

/// Screen 5: "تنظیمات ورزش و حرکت" (Section 5.5).
/// Single source of truth settings for sports, equipment, apartment mode, and cycle consent.
class MvSettingsScreen extends StatefulWidget {
  final MvUserProfile initialProfile;
  final ValueChanged<MvUserProfile> onProfileSaved;
  final VoidCallback? onRegenerateProgram;
  final dynamic controller;

  const MvSettingsScreen({
    super.key,
    required this.initialProfile,
    required this.onProfileSaved,
    this.onRegenerateProgram,
    this.controller,
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
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mv_settings_title),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: Text(
              l10n.mv_settings_save,
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
          // 0. Fixed Sports (Anchors) Section (S8-T4)
          _buildSectionHeader(l10n.mv_settings_anchors_section),
          _buildCard(
            children: [
              ListTile(
                key: const ValueKey('mv_settings_commitments_tile'),
                leading: Icon(
                  Icons.lock_clock,
                  color: colors.accent,
                  size: metrics.iconMd,
                ),
                title: Text(
                  l10n.mv_commitments_title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mv_week_anchor_cta_text,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: metrics.iconSm,
                  color: colors.textSecondary,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MvCommitmentsScreen(
                        controller: widget.controller is MvHubController
                            ? widget.controller as MvHubController
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 1. Program & Goal
          _buildSectionHeader(l10n.mv_settings_program_goals),
          _buildCard(
            children: [
              Text(l10n.mv_settings_days_per_week, style: textTheme.bodyMedium),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                children: [1, 2, 3, 4, 5, 6, 7].map((d) {
                  return MvChip(
                    label: l10n.mv_settings_n_days(d),
                    isSelected: _daysPerWeek == d,
                    onTap: () => setState(() => _daysPerWeek = d),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              Text(l10n.mv_settings_session_duration, style: textTheme.bodyMedium),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                children: _durations.map((dur) {
                  final label = dur == 'short'
                      ? l10n.mv_settings_dur_short
                      : dur == 'medium'
                      ? l10n.mv_settings_dur_medium
                      : l10n.mv_settings_dur_long;
                  return MvChip(
                    label: label,
                    isSelected: _duration == dur,
                    onTap: () => setState(() => _duration = dur),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              Text(l10n.mv_settings_default_intensity, style: textTheme.bodyMedium),
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
          _buildSectionHeader(l10n.mv_settings_env_equipment),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text(
                  l10n.mv_settings_neighbor_mode,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mv_settings_neighbor_desc,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _apartmentMode,
                onChanged: (v) => setState(() => _apartmentMode = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 3. Audio & Voice cues
          _buildSectionHeader(l10n.mv_settings_audio_section),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text(
                  l10n.mv_settings_voice_cues,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mv_settings_voice_desc,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _voiceEnabled,
                onChanged: (v) => setState(() => _voiceEnabled = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 4. Privacy & Menstrual Cycle Consent (AC-12, Rule 35)
          _buildSectionHeader(l10n.mv_settings_privacy_section),
          _buildCard(
            children: [
              SwitchListTile(
                title: Text(
                  l10n.mv_settings_cycle_consent,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.mv_settings_cycle_desc,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _cycleConsent,
                onChanged: (v) => setState(() => _cycleConsent = v),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 5. Advanced Actions
          if (widget.onRegenerateProgram != null) ...[
            _buildSectionHeader(l10n.mv_settings_advanced_section),
            _buildCard(
              children: [
                ListTile(
                  leading: Icon(Icons.refresh_rounded, color: colors.primary),
                  title: Text(
                    l10n.mv_settings_regen_title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    l10n.mv_settings_regen_desc,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
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
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
