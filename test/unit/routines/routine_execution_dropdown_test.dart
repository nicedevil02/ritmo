import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/features/routines/presentation/widgets/routine_type_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routine Execution Model Dropdown & As-Needed Defaults', () {
    test('RoutineTypePicker options include renamed as-needed and simple reminder', () {
      final asNeededOpt = RoutineTypePicker.options.firstWhere(
        (o) => o.type == RoutineType.asNeeded && o.itemType == 'ROUTINE',
      );
      expect(asNeededOpt.titleFa, equals('آزاد (شناور)'));
      expect(asNeededOpt.badgeFa, equals('پیش‌فرض'));

      final reminderOpt = RoutineTypePicker.options.firstWhere(
        (o) => o.itemType == 'REMINDER',
      );
      expect(reminderOpt.titleFa, equals('یادآور ساده'));
      expect(reminderOpt.badgeFa, equals('یادآور'));
    });

    test('PlannerController initializes with RoutineType.asNeeded and countUnit "بار"', () {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );

      expect(controller.routineType, equals(RoutineType.asNeeded));
      expect(controller.countUnit, equals('بار'));
    });

    test('PlannerController.setRoutineType updates routineType and itemType', () {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );

      controller.setRoutineType(RoutineType.timeBased, newItemType: 'REMINDER');
      expect(controller.routineType, equals(RoutineType.timeBased));
      expect(controller.itemType, equals('REMINDER'));

      controller.setRoutineType(RoutineType.countBased);
      expect(controller.routineType, equals(RoutineType.countBased));
      expect(controller.itemType, equals('ROUTINE'));
    });
  });
}
