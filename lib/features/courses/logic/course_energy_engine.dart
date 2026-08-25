import 'package:ritmo/features/courses/models/course_models.dart';

class CourseEnergyEngine {
  /// Filters and ranks candidate sessions based on current energy level (HIGH, MEDIUM, LOW)
  /// (Fixes C1)
  static List<CourseSession> filterAndRankForEnergy({
    required List<CourseSession> candidateSessions,
    required Map<String, Course> coursesMap,
    required String currentEnergyLevel,
  }) {
    final energy = currentEnergyLevel.toUpperCase();
    final filtered = <CourseSession>[];

    for (final session in candidateSessions) {
      final course = coursesMap[session.courseId];
      final energyRule = course?.energyRule ?? CourseEnergyRule.all;

      if (energy == 'LOW') {
        if (energyRule == CourseEnergyRule.skipLow ||
            energyRule == CourseEnergyRule.highOnly ||
            energyRule == CourseEnergyRule.mediumOrHigh) {
          continue; // Filter out
        }
        filtered.add(session);
      } else if (energy == 'MEDIUM') {
        if (energyRule == CourseEnergyRule.highOnly) {
          continue; // Filter out
        }
        filtered.add(session);
      } else {
        // HIGH energy: allow all
        filtered.add(session);
      }
    }

    // Sort/rank candidates
    filtered.sort((a, b) {
      final courseA = coursesMap[a.courseId];
      final courseB = coursesMap[b.courseId];

      final ruleA = courseA?.energyRule ?? CourseEnergyRule.all;
      final ruleB = courseB?.energyRule ?? CourseEnergyRule.all;

      final diffA = a.difficulty ?? 3;
      final diffB = b.difficulty ?? 3;

      if (energy == 'HIGH') {
        // High energy prefers highEnergyOnly rules and higher difficulty
        final scoreA = (ruleA == CourseEnergyRule.highOnly ? 10 : 0) + diffA;
        final scoreB = (ruleB == CourseEnergyRule.highOnly ? 10 : 0) + diffB;
        return scoreB.compareTo(scoreA);
      } else if (energy == 'LOW') {
        // Low energy prefers offerLight rules, lower difficulty first, then shorter duration.
        final offerBonusA = ruleA == CourseEnergyRule.offerLight ? -5 : 0;
        final offerBonusB = ruleB == CourseEnergyRule.offerLight ? -5 : 0;
        if (offerBonusA != offerBonusB) return offerBonusA.compareTo(offerBonusB);
        if (diffA != diffB) return diffA.compareTo(diffB);
        final durA = a.estimatedDurationMinutes ?? courseA?.sessionDurationMinutes ?? 45;
        final durB = b.estimatedDurationMinutes ?? courseB?.sessionDurationMinutes ?? 45;
        return durA.compareTo(durB);
      } else {
        // Medium energy: default display order or session number
        return a.displayOrder.compareTo(b.displayOrder);
      }
    });

    return filtered;
  }
}
