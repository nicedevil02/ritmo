import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

/// Recategorizes onboarding starter-pack routines that were incorrectly
/// created with the `fitness` category. The fitness category is owned by the
/// sports module, so editing these routines opened the sports form
/// (sport type / intensity / ...). These habits are generic personal
/// routines and should open the generic routine form instead.
class MigrationV96OnboardingStarterCategory extends Migration {
  @override
  int get version => 96;

  @override
  bool get requiresTransaction => true;

  static const List<String> _affectedIds = [
    'onboarding_routine_water_habit',
    'onboarding_routine_morning_stretch',
    'onboarding_routine_night_winddown',
  ];

  @override
  Future<void> up(DatabaseExecutor db) async {
    final ids = _affectedIds.map((id) => "'$id'").join(', ');
    await db.rawUpdate(
      "UPDATE routines SET category = 'personal' WHERE category = 'fitness' AND id IN ($ids)",
    );
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    final ids = _affectedIds.map((id) => "'$id'").join(', ');
    await db.rawUpdate(
      "UPDATE routines SET category = 'fitness' WHERE category = 'personal' AND id IN ($ids)",
    );
  }
}
