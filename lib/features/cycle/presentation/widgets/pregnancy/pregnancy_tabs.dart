// C-43, C-44: Pregnancy sub-tabs (Checkups, Kicks, Contractions, Symptoms)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/presentation/widgets/labor_mode_screen.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

class PregnancyCheckupsTab extends StatelessWidget {
  const PregnancyCheckupsTab({super.key, required this.currentWeek});

  final int currentWeek;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final checkupWindows = [
      {
        'id': 'chk_1',
        'title': 'مراقبت اول (هفته ۶ تا ۱۰)',
        'start': 6,
        'end': 10,
      },
      {
        'id': 'chk_2',
        'title': 'مراقبت دوم (غربالگری اول)',
        'start': 11,
        'end': 13,
      },
      {
        'id': 'chk_3',
        'title': 'مراقبت سوم (آنومالی هفته ۱۸ تا ۲۰)',
        'start': 18,
        'end': 20,
      },
      {
        'id': 'chk_4',
        'title': 'مراقبت چهارم (تست قند هفته ۲۴ تا ۲۸)',
        'start': 24,
        'end': 28,
      },
      {
        'id': 'chk_5',
        'title': 'مراقبت پنجم (هفته ۳۰ تا ۳۴)',
        'start': 30,
        'end': 34,
      },
      {
        'id': 'chk_6',
        'title': 'مراقبت ششم (هفته ۳۵ تا ۳۷)',
        'start': 35,
        'end': 37,
      },
      {
        'id': 'chk_7',
        'title': 'مراقبت هفتم (هفته ۳۸ تا ۴۰)',
        'start': 38,
        'end': 40,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      itemCount: checkupWindows.length,
      itemBuilder: (ctx, idx) {
        final item = checkupWindows[idx];
        final start = item['start'] as int;
        final end = item['end'] as int;
        final statusText = PregnancyHelpers.checkupWindowStatus(
          currentWeek: currentWeek,
          windowStartWeek: start,
          windowEndWeek: end,
          isCompleted: false,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          child: ListTile(
            title: Text(
              item['title'] as String,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              statusText,
              style: TextStyle(fontSize: 12, color: colors.primary),
            ),
            trailing: currentWeek >= start && currentWeek <= end
                ? TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('یادآوری مراقبت ثبت شد ⏰'),
                        ),
                      );
                    },
                    child: const Text(
                      'یادآوری',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class PregnancyKicksTab extends StatelessWidget {
  const PregnancyKicksTab({
    super.key,
    required this.kickCount,
    required this.onKickTap,
    this.targetCount = 10,
  });

  final int kickCount;
  final VoidCallback onKickTap;
  final int targetCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'جلسه واقعی «شمارش تا ${PersianDigits.toFa(targetCount.toString())}» حرکات جنین',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تعداد حرکات ثبت شده: ${PersianDigits.toFa(kickCount.toString())} / ${PersianDigits.toFa(targetCount.toString())}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onKickTap,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'ثبت حرکت 🦶',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PregnancyContractionsTab extends StatelessWidget {
  const PregnancyContractionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'انقباض‌سنج و حالت زایمان',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(CupertinoIcons.fullscreen, color: Colors.white),
            label: const Text(
              'ورود به حالت زایمان (تمام‌صفحه)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: () =>
                LaborModeScreen.show(context, pregnancyId: 'preg_default'),
          ),
        ],
      ),
    );
  }
}

class PregnancySymptomsTab extends StatelessWidget {
  const PregnancySymptomsTab({super.key, required this.noteController});

  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ثبت علائم و حالت امروز',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'یادداشت یا توضیحات امروز...',
              hintStyle: TextStyle(color: colors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
