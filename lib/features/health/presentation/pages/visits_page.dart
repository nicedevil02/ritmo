import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_summary_sheet.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visits_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';

import 'package:ritmo/features/health/presentation/pages/doctor_visit_form_page.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  final GlobalKey<DoctorVisitsSectionState> _sectionKey = GlobalKey<DoctorVisitsSectionState>();

  void _openDoctorVisitSummarySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const Directionality(
        textDirection: TextDirection.rtl,
        child: DoctorVisitSummarySheet(),
      ),
    );
  }

  void _openAddVisitPage() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => DoctorVisitFormPage(
          onSave: (visit) {
            _sectionKey.currentState?.saveVisit(visit);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: l10n.doctorVisits,
          showBackButton: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _openDoctorVisitSummarySheet,
                icon: Icon(CupertinoIcons.doc_text_fill, size: 14, color: colors.primary),
                label: Text(
                  'خلاصه برای پزشک',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: DoctorVisitsSection(key: _sectionKey),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: RitmoNeuButton(
              onTap: _openAddVisitPage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.add_circled_solid, color: colors.primary, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    l10n.doctorVisitsAddTitle,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

