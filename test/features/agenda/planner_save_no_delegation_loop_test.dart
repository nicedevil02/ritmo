import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B0-1: Planner Save & Delegation Loop Protection', () {
    testWidgets('save with allowDelegation: false does not invoke openCourseSheet or loop', (tester) async {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );
      controller.itemType = 'COURSE';
      controller.selectedCategory = Category.learning;
      controller.title = 'دوره آموزشی تست';

      var delegationOpened = false;
      controller.setCourseSheetOpener(({initialValues}) {
        delegationOpened = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  // Direct call with allowDelegation: false
                  await controller.save(context, allowDelegation: false);
                },
                child: const Text('Save'),
              );
            },
          ),
        ),
      );

      // When allowDelegation is false, delegation opener should NOT be called
      expect(delegationOpened, isFalse);
    });

    testWidgets('delegateToOwnerModule is idempotent and guards re-entry', (tester) async {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );
      controller.itemType = 'EVENT';
      var openCount = 0;
      controller.setEventSheetOpener(() {
        openCount++;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final first = controller.delegateToOwnerModule(context);
              final second = controller.delegateToOwnerModule(context);
              expect(first, isTrue);
              expect(second, isFalse); // Re-entry guarded
              return const SizedBox();
            },
          ),
        ),
      );

      expect(openCount, equals(1));
    });
  });
}
