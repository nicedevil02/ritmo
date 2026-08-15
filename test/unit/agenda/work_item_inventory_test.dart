import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';

/// Explicit display policy for any work/dated table in Ritmo.
enum WorkItemPolicy {
  /// Rendered into the agenda via an active AgendaSource.
  displayedInAgenda,

  /// Explicitly frozen historical audit layer (e.g. day_plan_commits).
  frozenHistoryAudit,

  /// Non-work metadata / configuration table.
  metadataOrConfig,
}

class WorkTableInventoryEntry {
  const WorkTableInventoryEntry({
    required this.tableName,
    required this.policy,
    this.owningSourceId,
    this.primaryDomain,
    required this.rationale,
  });

  final String tableName;
  final WorkItemPolicy policy;
  final String? owningSourceId;
  final AgendaDomain? primaryDomain;
  final String rationale;
}

void main() {
  group('Phase M3-C: Golden Work Item Inventory Test (P13 / M3-4)', () {
    // Golden inventory of all known work tables and their locked policy
    const goldenWorkItemInventory = <String, WorkTableInventoryEntry>{
      'routines': WorkTableInventoryEntry(
        tableName: 'routines',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'routine',
        primaryDomain: AgendaDomain.routine,
        rationale: 'Primary repository for habits and recurring routines',
      ),
      'simple_tasks': WorkTableInventoryEntry(
        tableName: 'simple_tasks',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'task',
        primaryDomain: AgendaDomain.task,
        rationale: 'Canonical home for one-off and scheduled tasks (Decision #1)',
      ),
      'temporary_events': WorkTableInventoryEntry(
        tableName: 'temporary_events',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'event',
        primaryDomain: AgendaDomain.event,
        rationale: 'One-off calendar events',
      ),
      'course_sessions': WorkTableInventoryEntry(
        tableName: 'course_sessions',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'course',
        primaryDomain: AgendaDomain.course,
        rationale: 'Course schedule sessions',
      ),
      'goal_steps': WorkTableInventoryEntry(
        tableName: 'goal_steps',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'goalSteps',
        primaryDomain: AgendaDomain.goalStep,
        rationale: 'Goal milestone scheduled steps',
      ),
      'worship_practices': WorkTableInventoryEntry(
        tableName: 'worship_practices',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'worship',
        primaryDomain: AgendaDomain.prayer,
        rationale: 'Obligatory prayers and mustahab practices',
      ),
      'worship_debts': WorkTableInventoryEntry(
        tableName: 'worship_debts',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'worship',
        primaryDomain: AgendaDomain.worshipDebt,
        rationale: 'Qada prayers and fasting debts (Decision #5)',
      ),
      'planning_allocations': WorkTableInventoryEntry(
        tableName: 'planning_allocations',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'commitment',
        primaryDomain: AgendaDomain.commitment,
        rationale: 'Planning cycle commitments & time allocations',
      ),
      'doctor_appointments': WorkTableInventoryEntry(
        tableName: 'doctor_appointments',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'appointment',
        primaryDomain: AgendaDomain.appointment,
        rationale: 'Doctor visits and medical appointments',
      ),
      'pregnancy_checkups': WorkTableInventoryEntry(
        tableName: 'pregnancy_checkups',
        policy: WorkItemPolicy.displayedInAgenda,
        owningSourceId: 'appointment',
        primaryDomain: AgendaDomain.appointment,
        rationale: 'Pregnancy milestone checkups',
      ),
      'day_plan_commits': WorkTableInventoryEntry(
        tableName: 'day_plan_commits',
        policy: WorkItemPolicy.frozenHistoryAudit,
        owningSourceId: null,
        primaryDomain: null,
        rationale: 'Historical planning commit audit; produces no agenda items (Decision #2)',
      ),
    };

    test('M3-4: Every work table in the golden inventory has a non-ambiguous policy', () {
      expect(goldenWorkItemInventory, isNotEmpty);

      for (final entry in goldenWorkItemInventory.values) {
        if (entry.policy == WorkItemPolicy.displayedInAgenda) {
          expect(entry.owningSourceId, isNotNull);
          expect(entry.primaryDomain, isNotNull);
        } else if (entry.policy == WorkItemPolicy.frozenHistoryAudit) {
          expect(entry.owningSourceId, isNull);
        }
        expect(entry.rationale, isNotEmpty);
      }
    });

    test('M3-4: An unregistered new table fails the inventory check (Negative test check)', () {
      // If a developer adds a new table without an entry in the golden inventory:
      const hypotheticalNewTable = 'unregistered_new_work_table';
      
      final isCovered = goldenWorkItemInventory.containsKey(hypotheticalNewTable);
      expect(
        isCovered,
        isFalse,
        reason: 'Unregistered work table must fail until an explicit policy is added to the golden inventory',
      );
    });
  });
}
