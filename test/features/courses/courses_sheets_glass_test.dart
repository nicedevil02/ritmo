import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/ai_syllabus_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/create_course_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/session_debrief_sheet.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/presentation/study_settings_sheet.dart';
import 'package:ritmo/features/study/presentation/widgets/session_timer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummySession = CourseSession(
    id: 'session_1',
    courseId: 'test_course_1',
    sessionNumber: 1,
    sessionTitle: 'جلسه اول: بردارها',
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );

  const dummyStudySettings = StudySettings(
    moduleEnabled: true,
    konkurMode: true,
    konkurSetupDone: true,
    dailyTargetMinutes: 120,
    focusBlockMinutes: 45,
    reviewEnabled: true,
    showInDashboard: true,
  );

  const dummySubject = StudySubject(
    id: 'sub_math_1',
    name: 'ریاضی تجربی',
  );

  group('Courses and Study Sheets Glassmorphism Tests', () {
    testWidgets('StudySettingsSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: const Scaffold(
            body: StudySettingsSheet(
              settings: dummyStudySettings,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('StudySettingsSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: const Scaffold(
            body: StudySettingsSheet(
              settings: dummyStudySettings,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('CreateCourseSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.copperDusk,
        brightness: Brightness.light,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: CreateCourseSheet(
              onCourseCreated: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('CreateCourseSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.copperDusk,
        brightness: Brightness.light,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: CreateCourseSheet(
              onCourseCreated: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('AiSyllabusSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: AiSyllabusSheet(
              onImported: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('AiSyllabusSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: AiSyllabusSheet(
              onImported: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('SessionDebriefSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: SessionDebriefSheet(
              session: dummySession,
              actualDurationMinutes: 45,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('SessionDebriefSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: SessionDebriefSheet(
              session: dummySession,
              actualDurationMinutes: 45,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('SessionTimerSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: const Scaffold(
            body: SessionTimerSheet(
              subject: dummySubject,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('SessionTimerSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: const Scaffold(
            body: SessionTimerSheet(
              subject: dummySubject,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
