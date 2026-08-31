import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/presentation/widgets/allergies_section.dart';
import 'package:ritmo/features/health/presentation/widgets/medical_documents_section.dart';
import 'package:ritmo/features/health/presentation/widgets/medical_profile_section.dart';
import 'package:ritmo/features/health/presentation/widgets/pregnancy_section.dart';
import 'package:ritmo/features/health/presentation/widgets/vaccinations_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool _showPregnancy = false;
  bool _isLoading = true;
  String? _expandedTileId;

  @override
  void initState() {
    super.initState();
    _checkPregnancyEligibility();
  }

  Future<void> _checkPregnancyEligibility() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};
      final pregnancyEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_pregnancy_enabled');
      final isFemale = CyclePrivacyGuard.isVisible(settingsMap);

      if (mounted) {
        setState(() {
          _showPregnancy = isFemale && pregnancyEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking pregnancy eligibility: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleTile(String tileId) {
    setState(() {
      if (_expandedTileId == tileId) {
        _expandedTileId = null;
      } else {
        _expandedTileId = tileId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: l10n.medicalProfile,
          showBackButton: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildCustomExpandableTile(
              id: 'PROFILE',
              title: l10n.medicalProfile,
              icon: CupertinoIcons.person_crop_circle,
              color: colors.primary,
              child: const MedicalProfileSection(),
            ),
            const SizedBox(height: 12),
            _buildCustomExpandableTile(
              id: 'DOCS',
              title: l10n.medicalDocuments,
              icon: CupertinoIcons.doc_richtext,
              color: colors.success,
              child: const MedicalDocumentsSection(),
            ),
            const SizedBox(height: 12),
            _buildCustomExpandableTile(
              id: 'VACCINES',
              title: l10n.vaccinations,
              icon: CupertinoIcons.shield_fill,
              color: colors.warning,
              child: const VaccinationsSection(),
            ),
            const SizedBox(height: 12),
            _buildCustomExpandableTile(
              id: 'ALLERGIES',
              title: l10n.allergies,
              icon: CupertinoIcons.exclamationmark_shield,
              color: colors.medicalRed,
              child: const AllergiesSection(),
            ),
            if (_showPregnancy) ...[
              const SizedBox(height: 12),
              _buildCustomExpandableTile(
                id: 'PREGNANCY',
                title: l10n.pregnancyTracker,
                icon: CupertinoIcons.heart_circle,
                color: colors.accent,
                child: const PregnancySection(),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomExpandableTile({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final colors = context.colors;
    final isExpanded = _expandedTileId == id;

    return RitmoCard.neumorphic(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleTile(id),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      color: colors.textSecondary,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: [
                      const RitmoCardDivider(),
                      child,
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

