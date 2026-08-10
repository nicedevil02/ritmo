import 'capacity_models.dart';
import 'commitment_scorer.dart';
import 'personalization_gate.dart';
import '../models/planning_models.dart';

class PartialAllocation {
  const PartialAllocation({
    required this.commitment,
    required this.placedMinutes,
    required this.missingMinutes,
  });

  final PlanningCommitment commitment;
  final int placedMinutes;
  final int missingMinutes;
}

class UnplacedCommitment {
  const UnplacedCommitment({
    required this.commitment,
    required this.reason,
    required this.detailFa,
  });

  final PlanningCommitment commitment;
  final UnplacedReason reason;
  final String detailFa;
}

class AllocationPlanResult {
  const AllocationPlanResult({
    required this.placed,
    required this.partial,
    required this.unplaced,
    required this.explanations,
  });

  final List<PlanningAllocation> placed;
  final List<PartialAllocation> partial;
  final List<UnplacedCommitment> unplaced;
  final Map<String, String> explanations;
}

class WeekAllocationEngine {
  const WeekAllocationEngine();

  /// حداکثر ۲ بلوک عمق‌یافته (DEEP) در هر روز
  static const int maxDeepBlocksPerDay = 2;

  /// حداقل مدت بلوک DEEP (زیر ۳۰ دقیقه ساخته نمی‌شود)
  static const int minDeepBlockMinutes = 30;

  /// مرز عدم پر کردن شکاف‌های کوچک ظرفیت (زیر ۲۰ دقیقه پر نمی‌شود)
  static const int antiFragmentationThresholdMinutes = 20;

  AllocationPlanResult allocate({
    required List<PlanningCommitment> commitments,
    required List<DayCapacity> capacities,
    required List<DayLoad> dayLoads,
    required String todayKey,
    Map<String, int>? daysToDeadlines,
    Map<String, double>? paceGaps,
    int energySamples = 0,
  }) {
    const scorer = CommitmentScorer();

    // 1) Filter ACCEPTED (or PROPOSED candidate) & Sort
    final active = commitments.where((c) => c.status != CommitmentStatus.dropped).toList();

    active.sort((a, b) {
      final impMap = {
        CommitmentImportance.must: 3,
        CommitmentImportance.should: 2,
        CommitmentImportance.could: 1,
      };
      final impA = impMap[a.importance] ?? 2;
      final impB = impMap[b.importance] ?? 2;

      if (impA != impB) return impB.compareTo(impA);

      final scoreA = scorer.score(
        c: a,
        todayKey: todayKey,
        daysToDeadline: daysToDeadlines?[a.id],
        goalPaceGap01: paceGaps?[a.goalId],
      );
      final scoreB = scorer.score(
        c: b,
        todayKey: todayKey,
        daysToDeadline: daysToDeadlines?[b.id],
        goalPaceGap01: paceGaps?[b.goalId],
      );

      if ((scoreA.total - scoreB.total).abs() > 0.001) {
        return scoreB.total.compareTo(scoreA.total);
      }

      return b.effortMinutes.compareTo(a.effortMinutes);
    });

    final placed = <PlanningAllocation>[];
    final partial = <PartialAllocation>[];
    final unplaced = <UnplacedCommitment>[];
    final explanations = <String, String>{};

    // Tracking state per day
    final remainingCap = <String, int>{
      for (final c in capacities) c.dayKey: c.committableMinutes
    };
    final deepCounts = <String, int>{
      for (final l in dayLoads) l.dayKey: l.deepCount
    };
    final loadMap = <String, DayLoad>{
      for (final l in dayLoads) l.dayKey: l
    };

    // Heavy days tracker
    final heavyDays = <String>{};

    for (final c in active) {
      var needed = c.effortMinutes;
      var placedForC = 0;

      final validDays = capacities.where((cap) {
        if (c.earliestDayKey != null && cap.dayKey.compareTo(c.earliestDayKey!) < 0) return false;
        if (c.latestDayKey != null && cap.dayKey.compareTo(c.latestDayKey!) > 0) return false;
        return true;
      }).toList();

      if (validDays.isEmpty) {
        unplaced.add(UnplacedCommitment(
          commitment: c,
          reason: UnplacedReason.noFreeSlot,
          detailFa: 'خارج از بازهٔ زمانی مجاز تعهد',
        ));
        continue;
      }

      // Check FIXED constraint
      if (c.flexibility == CommitmentFlexibility.fixed &&
          c.earliestDayKey != null &&
          c.earliestDayKey == c.latestDayKey) {
        final targetDay = c.earliestDayKey!;
        final rem = remainingCap[targetDay] ?? 0;
        if (rem < needed) {
          unplaced.add(UnplacedCommitment(
            commitment: c,
            reason: UnplacedReason.conflictsWithFixed,
            detailFa: 'در روز قفل‌شدهٔ $targetDay ظرفیت کافی وجود نداشت',
          ));
          continue;
        }
      }

      for (final cap in validDays) {
        if (needed <= 0) break;
        final dKey = cap.dayKey;
        final dLoad = loadMap[dKey];

        // Hard constraint C: Light day rule
        if (dLoad != null && dLoad.userMarkedLight) {
          if (c.workKind == WorkKind.deep) continue;
        }

        // Hard constraint D: Max 2 DEEP blocks per day
        if (c.workKind == WorkKind.deep && (deepCounts[dKey] ?? 0) >= maxDeepBlocksPerDay) {
          continue;
        }

        // Hard constraint E: Consecutive heavy days check
        var effectiveCap = remainingCap[dKey] ?? 0;
        final prevKey = _getPrevDayKey(dKey, capacities);
        final prevPrevKey = _getPrevDayKey(prevKey, capacities);
        if (heavyDays.contains(prevKey) && heavyDays.contains(prevPrevKey)) {
          effectiveCap = (effectiveCap * 0.6).round();
        }

        if (effectiveCap < antiFragmentationThresholdMinutes) continue;

        // Block sizing rules
        var blockSize = needed;
        if (needed >= 120) {
          blockSize = 60;
        } else if (needed > 60) {
          blockSize = 60;
        }

        if (c.workKind == WorkKind.deep && blockSize < minDeepBlockMinutes) {
          continue;
        }

        if (blockSize > effectiveCap) {
          blockSize = effectiveCap;
        }

        if (c.workKind == WorkKind.deep && blockSize < minDeepBlockMinutes) {
          continue;
        }

        if (blockSize <= 0) continue;

        final allocId = 'alloc_${c.id}_${dKey}_${placed.length}';
        final idempotencyKey = '${c.id}|$dKey|${placed.length}';

        final scoreBreakdown = scorer.score(
          c: c,
          todayKey: todayKey,
          daysToDeadline: daysToDeadlines?[c.id],
          goalPaceGap01: paceGaps?[c.goalId],
        );

        var reasonFa = scoreBreakdown.toReasonFa();
        if (const PersonalizationGate().allows(energySamples)) {
          reasonFa += ' (بر اساس الگوی انرژی‌ات با $energySamples داده)';
        }

        final alloc = PlanningAllocation(
          id: allocId,
          commitmentId: c.id,
          dayKey: dKey,
          plannedMinutes: blockSize,
          status: AllocationStatus.planned,
          idempotencyKey: idempotencyKey,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        placed.add(alloc);
        explanations[allocId] = reasonFa;

        remainingCap[dKey] = (remainingCap[dKey] ?? 0) - blockSize;
        if (c.workKind == WorkKind.deep) {
          deepCounts[dKey] = (deepCounts[dKey] ?? 0) + 1;
        }

        if ((capacities.firstWhere((cp) => cp.dayKey == dKey).committableMinutes - (remainingCap[dKey] ?? 0)) > 180) {
          heavyDays.add(dKey);
        }

        placedForC += blockSize;
        needed -= blockSize;
      }

      if (needed > 0 && placedForC > 0) {
        partial.add(PartialAllocation(
          commitment: c,
          placedMinutes: placedForC,
          missingMinutes: needed,
        ));
      } else if (needed > 0 && placedForC == 0) {
        unplaced.add(UnplacedCommitment(
          commitment: c,
          reason: UnplacedReason.capacityExceeded,
          detailFa: 'ظرفیت کافی در روزهای مجاز پیدا نشد',
        ));
      }
    }

    return AllocationPlanResult(
      placed: placed,
      partial: partial,
      unplaced: unplaced,
      explanations: explanations,
    );
  }

  String _getPrevDayKey(String currentKey, List<DayCapacity> caps) {
    final idx = caps.indexWhere((c) => c.dayKey == currentKey);
    if (idx > 0) return caps[idx - 1].dayKey;
    return '';
  }
}
