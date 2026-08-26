// lib/features/routines/domain/strategies/reflection_strategy.dart

import 'package:flutter/material.dart' show BuildContext;
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_category_strategy.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
import 'package:sqflite/sqflite.dart';

class ReflectionStrategy implements PlannerCategoryStrategy {
  const ReflectionStrategy();

  @override
  Category get category => Category.personal;

  @override
  bool matches(Category category, {String? itemType}) =>
      category == Category.personal && itemType == 'REFLECT';

  @override
  bool isModuleEnabled(Object controller) => true;

  @override
  Future<void> save(Object ctx, BuildContext context) async {
    final c = ctx as PlannerSaveContext;
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final todayStr = c.formatDate(c.selectedDate);

    final refId = 'reflection_$todayStr';
    final existing = await db.query(
       'daily_reflections',
       where: 'id = ?',
       whereArgs: [refId],
       limit: 1,
     );
     final values = {
       'date': todayStr,
       'mood_score': c.reflectionMood,
       'reflection_text': c.title,
       'learnings': c.reflectionLearnings.isNotEmpty ? c.reflectionLearnings : null,
       'gratitude': c.reflectionGratitude.isNotEmpty ? c.reflectionGratitude : null,
       'wins': c.reflectionWins.isNotEmpty ? c.reflectionWins : null,
       'challenges': null,
       'tomorrowFocus': null,
       'isPrivate': c.reflectionIsPrivate ? 1 : 0,
     };

     if (existing.isNotEmpty) {
       await db.update('daily_reflections', values, where: 'id = ?', whereArgs: [refId]);
     } else {
       await db.insert(
         'daily_reflections',
         {
           'id': refId,
           'createdAt': now,
           ...values,
         },
         conflictAlgorithm: ConflictAlgorithm.abort,
       );
     }
    RitmoEventBus().fire(RitmoEvent(
      type: 'ReflectionChanged',
      timestamp: DateTime.now(),
      payload: const {},
    ));
  }
}
