import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_bucket_section.dart';

void main() {
  Widget testHarness({required Widget sliver}) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [sliver],
        ),
      ),
    );
  }

  testWidgets('TaskBucketSection with empty tasks renders safely without sliver exceptions', (tester) async {
    await tester.pumpWidget(
      testHarness(
        sliver: TaskBucketSection(
          bucket: TaskBucket.overdue,
          tasks: const [],
          stepCounts: const {},
          attachmentCounts: const {},
          isExpanded: true,
          onToggleExpand: () {},
          onTaskTap: (_) {},
          onToggleDone: (_) {},
          onToggleStar: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('TaskBucketSection with tasks renders header and items properly', (tester) async {
    final now = DateTime.now();
    final task1 = SimpleTask(
      id: 'task_1',
      title: 'خرید کتاب',
      isDone: false,
      dueDate: '2026-08-21',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      testHarness(
        sliver: TaskBucketSection(
          bucket: TaskBucket.today,
          tasks: [task1],
          stepCounts: const {},
          attachmentCounts: const {},
          isExpanded: true,
          onToggleExpand: () {},
          onTaskTap: (_) {},
          onToggleDone: (_) {},
          onToggleStar: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('امروز'), findsOneWidget);
    expect(find.text('خرید کتاب'), findsOneWidget);
  });
}
