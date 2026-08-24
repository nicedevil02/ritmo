import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_summary_sheet.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visits_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class VisitsPage extends StatelessWidget {
  const VisitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    const identityColor = Color(0xff10B981); // Visits Green

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
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: identityColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.calendar_badge_plus, color: identityColor, size: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.doctorVisits,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: openDoctorVisitSummarySheet,
                icon: const Icon(Icons.description_outlined, size: 15, color: Color(0xff10B981)),
                label: const Text(
                  'خلاصه برای پزشک',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: Color(0xff10B981),
                  ),
                ),
              ),
            ),
          ],
          centerTitle: false,
        ),
        body: const SingleChildScrollView(
          child: DoctorVisitsSection(),
        ),
      ),
    );
  }
}
