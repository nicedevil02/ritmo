import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_summary_sheet.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visits_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class VisitsPage extends StatelessWidget {
  const VisitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    void openDoctorVisitSummarySheet() {
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
                onPressed: openDoctorVisitSummarySheet,
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
        body: const SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: DoctorVisitsSection(),
        ),
      ),
    );
  }
}

