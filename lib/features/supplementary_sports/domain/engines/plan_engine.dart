import 'package:shamsi_date/shamsi_date.dart';
import '../models/models.dart';

/// 7.3 PlanEngine: Generates and harmonizes weekly workout and movement plans.
///
/// Merges legacy generators into one single, explainable brain.
class PlanEngine {
  const PlanEngine();

  /// S3-T4: Six-stage week generation engine.
  MvPlanResult generateWeek({
    required DateTime weekStartSat,
    required MvUserProfile profile,
    required List<MvCommitment> commitments,
    required List<MvSlotOverride> overrides,
    required Map<String, MvMovementKind> kinds,
    required Map<String, MvKindProfile> kindProfiles,
    required MvBudgetSnapshot budget,
    required MvLoadSnapshot? load,
    required MvReadinessTier readiness,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final weekDays = MvCalendar.getWeekDays(weekStartSat);

    // 1. ANCHORS
    final initialAnchorSlots = _placeAnchors(
      weekStartSat: weekStartSat,
      commitments: commitments,
      overrides: overrides,
      kinds: kinds,
    );

    // 2. HARD_LIMITS (S3-T5)
    final hardLimits = _applyHardLimits(
      weekStartSat: weekStartSat,
      profile: profile,
      anchorSlots: initialAnchorSlots,
      kinds: kinds,
    );

    final anchorSlots = hardLimits.annotatedSlots;
    final notes = List<String>.from(hardLimits.notes);

    final stageDecisions = <MvDecision>[
      MvDecision<List<MvSlot>>(
        value: anchorSlots,
        reasonFa: 'اسلات‌های لنگر ثابت هفتگی جانمایی شدند.',
        reasonKey: MvReasonKeys.anchor,
        sources: const ['commitments', 'overrides'],
      ),
      MvDecision<Map<String, MvMovementKind>>(
        value: hardLimits.allowedKinds,
        reasonFa: 'فیلتر محدودیت‌های قطعی جسمی، آپارتمان و فصل اعمال شد.',
        reasonKey: MvReasonKeys.seasonFit,
        sources: const ['profile', 'season'],
      ),
    ];

    final slotsByDay = <String, List<MvSlot>>{};
    for (final slot in anchorSlots) {
      slotsByDay.putIfAbsent(slot.dateIso, () => []).add(slot);
    }

    final initialFullWeekSlots = <MvSlot>[];
    for (int i = 0; i < 7; i++) {
      final dayDate = weekDays[i];
      final dayIso = MvCalendar.formatDateIso(dayDate);
      final dayAnchors = slotsByDay[dayIso];

      if (dayAnchors != null && dayAnchors.isNotEmpty) {
        initialFullWeekSlots.addAll(dayAnchors);
      } else {
        initialFullWeekSlots.add(
          MvSlot(
            id: 'slot_${dayIso}_rest',
            dateIso: dayIso,
            cycleWeek: 1,
            slotType: MvSlotType.rest,
            targetMinutes: 0,
            intensityTier: MvIntensityTier.light,
            headlineFa: 'روز استراحت و ریکاوری',
            coachNoteFa:
                'به عضلاتت فرصت بازسازی بده یا با پیاده‌روی سبک جریان خون را تقویت کن.',
            source: 'GENERATED',
            reasonKey: MvReasonKeys.restGuaranteed,
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    // 3. ADJACENCY (S3-T6: ADJ-1..ADJ-7)
    final adjacency = _applyAdjacency(
      weekStartSat: weekStartSat,
      weekSlots: initialFullWeekSlots,
      kinds: kinds,
      kindProfiles: kindProfiles,
    );

    stageDecisions.add(
      MvDecision<List<MvSlot>>(
        value: adjacency.slots,
        reasonFa:
            'قواعد مجاورت لنگرها، تحرک قبل، ریکاوری بعد و فواصل تمرینی اعمال شد.',
        reasonKey: MvReasonKeys.preAnchorTaper,
        sources: const ['calendar', 'commitments'],
      ),
    );

    // 4. FILL (S3-T7: _fillToTarget)
    final filledSlots = _fillToTarget(
      slots: adjacency.slots,
      profile: profile,
      kinds: kinds,
      allowedKinds: hardLimits.allowedKinds,
      kindProfiles: kindProfiles,
      budget: budget,
      load: load,
    );

    stageDecisions.add(
      MvDecision<List<MvSlot>>(
        value: filledSlots,
        reasonFa:
            'اسلات‌های تکمیلی قدرتی و کسری فعالیت هفتگی تا سقف مجاز افزوده شدند.',
        reasonKey: MvReasonKeys.whoGap,
        sources: const ['budget', 'load'],
      ),
    );

    return MvPlanResult(
      slots: filledSlots,
      stageDecisions: stageDecisions,
      notes: notes,
      allowedKinds: hardLimits.allowedKinds,
      hasConflict: adjacency.hasConflict,
      conflictNote: adjacency.conflictNote,
    );
  }

  /// مرحلهٔ ۴: پرکردن تا هدف بودجهٔ هفتگی با سقف رشد و حداقل ۲ روز قدرتی (S3-T7)
  List<MvSlot> _fillToTarget({
    required List<MvSlot> slots,
    required MvUserProfile profile,
    required Map<String, MvMovementKind> kinds,
    required Map<String, MvMovementKind> allowedKinds,
    required Map<String, MvKindProfile> kindProfiles,
    required MvBudgetSnapshot budget,
    required MvLoadSnapshot? load,
  }) {
    final updatedSlots = List<MvSlot>.from(slots);
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Calculate current planned moderate equivalent minutes
    int currentEquivMinutes = 0;
    int currentStrengthDays = 0;

    for (final s in updatedSlots) {
      if (s.slotType == MvSlotType.strength) {
        currentStrengthDays++;
      }
      final kind = allowedKinds[s.kindCode] ?? kinds[s.kindCode];
      final baseMet = kind?.baseMet ??
          (s.slotType == MvSlotType.strength
              ? 4.5
              : (s.slotType == MvSlotType.mobility ? 2.5 : 3.5));
      if (s.targetMinutes > 0) {
        if (baseMet >= 6.0) {
          currentEquivMinutes += s.targetMinutes * 2;
        } else if (baseMet >= 3.0) {
          currentEquivMinutes += s.targetMinutes;
        }
      }
    }

    // 2. Priority 1: Strength Day Shortfall (up to strengthDaysTarget, default 2)
    final strengthTarget = budget.strengthDaysTarget;
    if (currentStrengthDays < strengthTarget) {
      final neededStrengthDays = strengthTarget - currentStrengthDays;
      int strengthAdded = 0;

      // Pass 1: pure rest days
      for (int i = 0; i < 7; i++) {
        if (strengthAdded >= neededStrengthDays) break;
        if (!updatedSlots[i].isLocked &&
            updatedSlots[i].slotType == MvSlotType.rest) {
          final nextDay = (i + 1) % 7;
          if (updatedSlots[nextDay].isLocked) {
            continue;
          }

          final strengthDuration =
              _parseDuration(profile.sessionDuration, false);
          updatedSlots[i] = MvSlot(
            id: 'slot_${updatedSlots[i].dateIso}_strength',
            dateIso: updatedSlots[i].dateIso,
            cycleWeek: updatedSlots[i].cycleWeek,
            slotType: MvSlotType.strength,
            kindCode: 'BODYWEIGHT',
            focusCodes: const ['FULL_BODY'],
            targetMinutes: strengthDuration,
            intensityTier: profile.defaultIntensity,
            targetRpe: profile.defaultIntensity.targetRpe,
            headlineFa: 'تمرین قدرتی و تقویت عضلات',
            coachNoteFa: 'تقویت سیستم عضلانی و اسکلتی برای تثبیت فرم بدنی.',
            source: 'GENERATED',
            reasonKey: MvReasonKeys.strengthQuota,
            reasonParams: {'days': strengthTarget.toString()},
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          );
          strengthAdded++;
          currentStrengthDays++;
          currentEquivMinutes += strengthDuration;
        }
      }

      // Pass 2: other non-locked days if needed (excluding day before anchor per ADJ-7)
      if (strengthAdded < neededStrengthDays) {
        for (int i = 0; i < 7; i++) {
          if (strengthAdded >= neededStrengthDays) break;
          if (!updatedSlots[i].isLocked &&
              updatedSlots[i].slotType != MvSlotType.strength) {
            final nextDay = (i + 1) % 7;
            if (updatedSlots[nextDay].isLocked) {
              continue;
            }

            final strengthDuration =
                _parseDuration(profile.sessionDuration, false);
            updatedSlots[i] = MvSlot(
              id: 'slot_${updatedSlots[i].dateIso}_strength',
              dateIso: updatedSlots[i].dateIso,
              cycleWeek: updatedSlots[i].cycleWeek,
              slotType: MvSlotType.strength,
              kindCode: 'BODYWEIGHT',
              focusCodes: const ['FULL_BODY'],
              targetMinutes: strengthDuration,
              intensityTier: profile.defaultIntensity,
              targetRpe: profile.defaultIntensity.targetRpe,
              headlineFa: 'تمرین قدرتی و تقویت عضلات',
              coachNoteFa: 'تقویت سیستم عضلانی و اسکلتی برای تثبیت فرم بدنی.',
              source: 'GENERATED',
              reasonKey: MvReasonKeys.strengthQuota,
              reasonParams: {'days': strengthTarget.toString()},
              status: MvSlotStatus.planned,
              createdAt: now,
              updatedAt: now,
            );
            strengthAdded++;
            currentStrengthDays++;
            currentEquivMinutes += strengthDuration;
          }
        }
      }
    }

    // 3. Priority 3: Moderate equivalent minutes gap (up to budget.targetMin, default 150)
    final targetMin = budget.targetMin;
    if (currentEquivMinutes < targetMin) {
      final gap = targetMin - currentEquivMinutes;
      // If there are still open rest days, add light aerobic / walking / cardio filler
      for (int i = 0; i < 7; i++) {
        if (currentEquivMinutes >= targetMin) break;
        if (!updatedSlots[i].isLocked &&
            updatedSlots[i].slotType == MvSlotType.rest) {
          final nextDay = (i + 1) % 7;
          if (updatedSlots[nextDay].isLocked) continue;

          final fillMinutes = gap.clamp(15, 45);
          updatedSlots[i] = MvSlot(
            id: 'slot_${updatedSlots[i].dateIso}_filler',
            dateIso: updatedSlots[i].dateIso,
            cycleWeek: updatedSlots[i].cycleWeek,
            slotType: MvSlotType.cardio,
            kindCode: 'WALKING',
            targetMinutes: fillMinutes,
            intensityTier: MvIntensityTier.moderate,
            targetRpe: 5,
            headlineFa: 'پیاده‌روی تند و هوازی سبک',
            coachNoteFa:
                'تکمیل سهمیه هفتگی فعالیت بدنی برای ارتقای سلامت قلب و عروق.',
            source: 'GENERATED',
            reasonKey: MvReasonKeys.whoGap,
            reasonParams: {'remaining': gap.toString()},
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          );
          currentEquivMinutes += fillMinutes;
        }
      }
    }

    return updatedSlots;
  }

  /// مرحلهٔ ۳: اعمال قواعد مجاورت ADJ-1 تا ADJ-7 (S3-T6)
  _AdjacencyOutput _applyAdjacency({
    required DateTime weekStartSat,
    required List<MvSlot> weekSlots,
    required Map<String, MvMovementKind> kinds,
    required Map<String, MvKindProfile> kindProfiles,
  }) {
    final updatedSlots = List<MvSlot>.from(weekSlots);
    bool hasConflict = false;
    String? conflictNote;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Find days with anchors
    final anchorDayIndices = <int>[];
    for (int i = 0; i < 7; i++) {
      if (updatedSlots[i].isLocked) {
        anchorDayIndices.add(i);
      }
    }

    // ADJ-2 & ADJ-3: Taper (day before) and Recovery (day after) for each anchor
    for (final dayIdx in anchorDayIndices) {
      final anchorSlot = updatedSlots[dayIdx];
      final kind = kinds[anchorSlot.kindCode];
      final isHighImpact = (kind?.jointImpact ?? 2) >= 2 ||
          (anchorSlot.targetMinutes >= 60);

      // ADJ-2: Day before (i - 1) -> mobility, max 20 min, light
      final dayBefore = (dayIdx - 1 + 7) % 7;
      if (!updatedSlots[dayBefore].isLocked &&
          updatedSlots[dayBefore].reasonKey !=
              MvReasonKeys.postAnchorRecovery) {
        final kindTitle = kind?.titleFa ?? 'ورزش لنگر';
        updatedSlots[dayBefore] = MvSlot(
          id: 'slot_${updatedSlots[dayBefore].dateIso}_mobility',
          dateIso: updatedSlots[dayBefore].dateIso,
          cycleWeek: updatedSlots[dayBefore].cycleWeek,
          slotType: MvSlotType.mobility,
          targetMinutes: 20,
          intensityTier: MvIntensityTier.light,
          headlineFa: 'تحرک و آمادگی قبل از $kindTitle',
          coachNoteFa:
              'تمرینات موبیلیتی سبک و کشش پویا برای آمادگی بهتر در روز لنگر.',
          source: 'GENERATED',
          reasonKey: MvReasonKeys.preAnchorTaper,
          reasonParams: {'kind': kindTitle},
          status: MvSlotStatus.planned,
          createdAt: now,
          updatedAt: now,
        );
      }

      // ADJ-3: Day after (i + 1) -> activeRest, max 25 min (ONLY if high-impact anchor)
      final dayAfter = (dayIdx + 1) % 7;
      if (isHighImpact && !updatedSlots[dayAfter].isLocked) {
        final kindTitle = kind?.titleFa ?? 'ورزش لنگر';
        updatedSlots[dayAfter] = MvSlot(
          id: 'slot_${updatedSlots[dayAfter].dateIso}_active_rest',
          dateIso: updatedSlots[dayAfter].dateIso,
          cycleWeek: updatedSlots[dayAfter].cycleWeek,
          slotType: MvSlotType.activeRest,
          targetMinutes: 25,
          intensityTier: MvIntensityTier.light,
          headlineFa: 'بازیابی فعال بعد از $kindTitle',
          coachNoteFa:
              'پیاده‌روی آرام و حرکات ریکاوری برای تخلیه لاکتات و رفع خستگی عضلانی.',
          source: 'GENERATED',
          reasonKey: MvReasonKeys.postAnchorRecovery,
          reasonParams: {'kind': kindTitle},
          status: MvSlotStatus.planned,
          createdAt: now,
          updatedAt: now,
        );
      }
    }

    // ADJ-6: Check for consecutive high-impact anchors
    for (int idx = 0; idx < anchorDayIndices.length - 1; idx++) {
      final dayA = anchorDayIndices[idx];
      final dayB = anchorDayIndices[idx + 1];
      if (dayB == dayA + 1) {
        final kindA = kinds[updatedSlots[dayA].kindCode];
        final kindB = kinds[updatedSlots[dayB].kindCode];
        final isHighImpactA = (kindA?.jointImpact ?? 2) >= 2 ||
            (updatedSlots[dayA].targetMinutes >= 60);
        final isHighImpactB = (kindB?.jointImpact ?? 2) >= 2 ||
            (updatedSlots[dayB].targetMinutes >= 60);

        if (isHighImpactA && isHighImpactB) {
          hasConflict = true;
          conflictNote = 'mv_conflict_back_to_back';

          // Day after the second anchor: mandatory activeRest
          final dayAfterB = (dayB + 1) % 7;
          if (!updatedSlots[dayAfterB].isLocked) {
            final kindTitle = kindB?.titleFa ?? 'ورزش لنگر';
            updatedSlots[dayAfterB] = MvSlot(
              id: 'slot_${updatedSlots[dayAfterB].dateIso}_active_rest',
              dateIso: updatedSlots[dayAfterB].dateIso,
              cycleWeek: updatedSlots[dayAfterB].cycleWeek,
              slotType: MvSlotType.activeRest,
              targetMinutes: 25,
              intensityTier: MvIntensityTier.light,
              headlineFa: 'بازیابی فعال بعد از دو روز پرفشار',
              coachNoteFa:
                  'پیاده‌روی سبک یا حرکات کششی آرام برای تسریع بازسازی عضلانی.',
              source: 'GENERATED',
              reasonKey: MvReasonKeys.postAnchorRecovery,
              reasonParams: {'kind': kindTitle},
              status: MvSlotStatus.planned,
              createdAt: now,
              updatedAt: now,
            );
          }
        }
      }
    }

    // ADJ-5: If >= 3 anchors in the week, guarantee at least 1 full rest day
    if (anchorDayIndices.length >= 3) {
      final hasRest = updatedSlots.any((s) => !s.isLocked && s.slotType == MvSlotType.rest);
      if (!hasRest) {
        for (int i = 0; i < 7; i++) {
          if (!updatedSlots[i].isLocked) {
            updatedSlots[i] = MvSlot(
              id: 'slot_${updatedSlots[i].dateIso}_rest',
              dateIso: updatedSlots[i].dateIso,
              cycleWeek: updatedSlots[i].cycleWeek,
              slotType: MvSlotType.rest,
              targetMinutes: 0,
              intensityTier: MvIntensityTier.light,
              headlineFa: 'روز استراحت و ریکاوری',
              coachNoteFa:
                  'به دلیل ۳ جلسه لنگر در این هفته، این روز برای استراحت کامل بدنت در نظر گرفته شده است.',
              source: 'GENERATED',
              reasonKey: MvReasonKeys.restGuaranteed,
              status: MvSlotStatus.planned,
              createdAt: now,
              updatedAt: now,
            );
            break;
          }
        }
      }
    }

    return _AdjacencyOutput(
      slots: updatedSlots,
      hasConflict: hasConflict,
      conflictNote: conflictNote,
    );
  }

  /// مرحلهٔ ۲: اعمال محدودیت‌های قطعی تقویم، جسمی، آپارتمان و فصل (S3-T5)
  _HardLimitsOutput _applyHardLimits({
    required DateTime weekStartSat,
    required MvUserProfile profile,
    required List<MvSlot> anchorSlots,
    required Map<String, MvMovementKind> kinds,
  }) {
    final notes = <String>[];
    final annotatedAnchors = <MvSlot>[];

    final hasKneeLimitation = profile.physicalLimitations.any(
      (l) =>
          l.toLowerCase().contains('knee') ||
          l.toLowerCase().contains('زانو'),
    );
    final isNeighborFriendly = profile.neighborFriendly;

    // 1. Check anchor constraints (Anchors are exempt from removal, but annotated)
    for (final slot in anchorSlots) {
      final kind = kinds[slot.kindCode];
      bool hasConstraintConflict = false;
      String? constraintWarning;

      if (hasKneeLimitation && kind != null && kind.jointImpact >= 3) {
        hasConstraintConflict = true;
        constraintWarning =
            'محدودیت زانو: لطفاً با گرم‌کردن کافی و احتیاط تمرین کنید.';
      }

      if (hasConstraintConflict) {
        notes.add('mv_anchor_constraint_note');
        annotatedAnchors.add(
          slot.copyWith(
            coachNoteFa: constraintWarning ?? slot.coachNoteFa,
            reasonParams: {
              ...?slot.reasonParams,
              'constraintNote': 'mv_anchor_constraint_note',
            },
          ),
        );
      } else {
        annotatedAnchors.add(slot);
      }
    }

    // 2. Filter allowed filler kinds
    final allowedKinds = <String, MvMovementKind>{};

    for (final entry in kinds.entries) {
      final kind = entry.value;

      // Season filter: check month matching if seasonMask specified
      if (!_isKindInSeason(kind, weekStartSat)) {
        continue; // Out of season
      }

      // Knee physical limitation: exclude high joint impact (>= 3)
      if (hasKneeLimitation && kind.jointImpact >= 3) {
        continue;
      }

      // Neighbor friendly (apartment mode): exclude high impact if indoors
      if (isNeighborFriendly && !kind.isOutdoor && kind.jointImpact >= 3) {
        continue;
      }

      allowedKinds[entry.key] = kind;
    }

    return _HardLimitsOutput(
      annotatedSlots: annotatedAnchors,
      allowedKinds: allowedKinds,
      notes: notes,
    );
  }

  static bool _isKindInSeason(MvMovementKind kind, DateTime date) {
    if (kind.seasonMask == null || kind.seasonMask!.trim().isEmpty) return true;
    final jDate = Jalali.fromDateTime(date);
    final currentMonth = jDate.month.toString(); // 1..12
    final months =
        kind.seasonMask!.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty);
    return months.contains(currentMonth);
  }

  /// مرحلهٔ ۱: جانمایی لنگرها (S3-T4)
  List<MvSlot> _placeAnchors({
    required DateTime weekStartSat,
    required List<MvCommitment> commitments,
    required List<MvSlotOverride> overrides,
    required Map<String, MvMovementKind> kinds,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final placed = <MvSlot>[];

    for (final c in commitments) {
      if (!c.isActive) continue;

      final dayDate = weekStartSat.add(Duration(days: c.dayOfWeekSat0));
      final dayIso = MvCalendar.formatDateIso(dayDate);

      // Check active date window
      if (c.startDateIso != null && dayIso.compareTo(c.startDateIso!) < 0) {
        continue;
      }
      if (c.endDateIso != null && dayIso.compareTo(c.endDateIso!) > 0) {
        continue;
      }

      // Check if this date has a skip/cancellation override
      final isOverridden = overrides.any(
        (o) =>
            o.dateIso == dayIso &&
            (o.action.toUpperCase() == 'SKIP' ||
                o.action.toUpperCase() == 'CANCEL'),
      );
      if (isOverridden) continue;

      final kind = kinds[c.kindCode];
      final family = kind?.family ?? MovementFamily.sport;
      final slotType = _deriveSlotType(family);

      placed.add(
        MvSlot(
          id: 'anchor_${dayIso}_${c.id ?? c.kindCode}',
          dateIso: dayIso,
          cycleWeek: 1,
          slotType: slotType,
          kindCode: c.kindCode,
          plannedTime: c.startTime,
          focusCodes: const [],
          targetMinutes: c.durationMinutes,
          intensityTier: MvIntensityTier.moderate,
          headlineFa: (c.titleFa != null && c.titleFa!.isNotEmpty)
              ? c.titleFa!
              : (kind?.titleFa ?? 'ورزش لنگر'),
          coachNoteFa: null,
          source: 'ANCHOR',
          sourceRef: c.id?.toString(),
          isLocked: true,
          status: MvSlotStatus.planned,
          reasonKey: MvReasonKeys.anchor,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return placed;
  }

  static MvSlotType _deriveSlotType(MovementFamily family) {
    switch (family) {
      case MovementFamily.sport:
        return MvSlotType.sport;
      case MovementFamily.outdoor:
        return MvSlotType.outdoor;
      case MovementFamily.endurance:
        return MvSlotType.cardio;
      case MovementFamily.strength:
        return MvSlotType.strength;
      case MovementFamily.mindBody:
        return MvSlotType.mobility;
      case MovementFamily.martialSkill:
        return MvSlotType.sport;
      case MovementFamily.daily:
        return MvSlotType.activeRest;
    }
  }

  /// Generates 7 slots for the week starting at [weekSaturday] (Legacy compatibility).
  MvDecision<List<MvSlot>> generateWeekPlan({
    required MvUserProfile profile,
    required DateTime weekSaturday,
    List<MvSlot> existingSlots = const [],
    int totalCycleWeeks = 4,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final weekDays = MvCalendar.getWeekDays(weekSaturday);
    final startDate = profile.programStartDate != null
        ? MvCalendar.parseDateIso(profile.programStartDate!)
        : weekSaturday;
    final cycleWeek = MvCalendar.cycleWeekFor(
      targetDate: weekSaturday,
      programStartDate: startDate,
      totalWeeks: totalCycleWeeks,
    );
    final isDeload = MvCalendar.isDeloadWeek(
      cycleWeek,
      deloadEveryNWeeks: profile.deloadEveryNWeeks,
    );

    final targetMinutes = _parseDuration(profile.sessionDuration, isDeload);
    final slots = <MvSlot>[];

    final musclePlan = _buildMuscleDistribution(profile.trainingDays, isDeload);

    for (int i = 0; i < 7; i++) {
      final dayDate = weekDays[i];
      final dayIso = MvCalendar.formatDateIso(dayDate);
      final sat0 = i;

      final existingLocked = existingSlots
          .where((s) => s.dateIso == dayIso && s.isLocked)
          .firstOrNull;
      if (existingLocked != null) {
        slots.add(
          existingLocked.copyWith(
            reasonKey: existingLocked.reasonKey ?? MvReasonKeys.anchor,
          ),
        );
        continue;
      }

      final isTrainingDay = profile.trainingDays.contains(sat0);
      if (!isTrainingDay) {
        slots.add(
          MvSlot(
            id: 'slot_${dayIso}_rest',
            dateIso: dayIso,
            cycleWeek: cycleWeek,
            slotType: MvSlotType.rest,
            targetMinutes: 0,
            intensityTier: MvIntensityTier.light,
            headlineFa: 'روز استراحت و ریکاوری',
            coachNoteFa:
                'به عضلاتت فرصت بازسازی بده یا با پیاده‌روی سبک جریان خون را تقویت کن.',
            source: 'GENERATED',
            reasonKey: MvReasonKeys.restGuaranteed,
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        final dayFocus = musclePlan[sat0] ?? ['FULL_BODY'];
        final headline = _generateHeadline(dayFocus, isDeload);
        final intensity = isDeload
            ? MvIntensityTier.light
            : profile.defaultIntensity;

        slots.add(
          MvSlot(
            id: 'slot_$dayIso',
            dateIso: dayIso,
            cycleWeek: cycleWeek,
            slotType: MvSlotType.strength,
            kindCode: 'BODYWEIGHT',
            focusCodes: dayFocus,
            targetMinutes: targetMinutes,
            intensityTier: intensity,
            targetRpe: intensity.targetRpe,
            headlineFa: headline,
            coachNoteFa: isDeload
                ? 'این هفته سبک‌تر تمرین می‌کنیم تا بدنت ریکاوری شود و برای هفتهٔ بعد آماده باشی.'
                : 'تمرکز روی کنترل حرکت و انقباض مناسب عضلات.',
            source: 'GENERATED',
            reasonKey: MvReasonKeys.strengthQuota,
            reasonParams: {'days': profile.trainingDays.length.toString()},
            status: MvSlotStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    String reasonFa =
        'برنامهٔ هفتهٔ $cycleWeek با ${profile.trainingDays.length} روز فعال تنظیم شد.';
    if (isDeload) {
      reasonFa += ' این هفته به عنوان «هفتهٔ سبک» با حجم کمتر تنظیم شده است.';
    }

    return MvDecision<List<MvSlot>>(
      value: slots,
      reasonFa: reasonFa,
      reasonKey: MvReasonKeys.strengthQuota,
      reasonParams: {'days': profile.trainingDays.length.toString()},
      sources: const ['profile', 'calendar'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }

  int _parseDuration(String duration, bool isDeload) {
    int baseMinutes = 30;
    switch (duration.toLowerCase()) {
      case 'short':
      case '15':
        baseMinutes = 15;
        break;
      case 'long':
      case '45':
      case '60':
        baseMinutes = 45;
        break;
      case 'medium':
      case '30':
      default:
        baseMinutes = 30;
    }
    if (isDeload) {
      baseMinutes = (baseMinutes * 0.6).round().clamp(10, 45);
    }
    return baseMinutes;
  }

  Map<int, List<String>> _buildMuscleDistribution(
    List<int> trainingDays,
    bool isDeload,
  ) {
    final map = <int, List<String>>{};
    final count = trainingDays.length;

    if (count <= 2) {
      for (final day in trainingDays) {
        map[day] = ['FULL_BODY'];
      }
    } else if (count == 3) {
      map[trainingDays[0]] = ['CHEST', 'TRICEPS', 'SHOULDER']; // Push / Upper
      map[trainingDays[1]] = ['QUADS_GLUTES', 'HAMSTRINGS', 'CALVES']; // Lower
      map[trainingDays[2]] = ['BACK', 'BICEPS', 'CORE']; // Pull / Back
    } else if (count == 4) {
      map[trainingDays[0]] = ['UPPER'];
      map[trainingDays[1]] = ['LOWER'];
      map[trainingDays[2]] = ['UPPER'];
      map[trainingDays[3]] = ['LOWER', 'CORE'];
    } else {
      for (int i = 0; i < count; i++) {
        final day = trainingDays[i];
        if (i % 3 == 0) map[day] = ['UPPER'];
        if (i % 3 == 1) map[day] = ['LOWER'];
        if (i % 3 == 2) map[day] = ['CORE', 'CARDIO'];
      }
    }
    return map;
  }

  String _generateHeadline(List<String> focus, bool isDeload) {
    final prefix = isDeload ? 'سبک: ' : '';
    if (focus.contains('FULL_BODY')) return '$prefixتمرین کل بدن';
    if (focus.contains('QUADS_GLUTES') || focus.contains('LOWER'))
      return '$prefixقدرت و استقامت پایین‌تنه';
    if (focus.contains('CHEST') || focus.contains('UPPER'))
      return '$prefixقدرت بالاتنه و سینه';
    if (focus.contains('BACK')) return '$prefixتقویت عضلات پشت و بازو';
    if (focus.contains('CORE')) return '$prefixتمرین مرکز بدن و شکم';
    return '$prefixجلسهٔ قدرتی';
  }
}

class _HardLimitsOutput {
  final List<MvSlot> annotatedSlots;
  final Map<String, MvMovementKind> allowedKinds;
  final List<String> notes;

  const _HardLimitsOutput({
    required this.annotatedSlots,
    required this.allowedKinds,
    this.notes = const [],
  });
}

class _AdjacencyOutput {
  final List<MvSlot> slots;
  final bool hasConflict;
  final String? conflictNote;

  const _AdjacencyOutput({
    required this.slots,
    this.hasConflict = false,
    this.conflictNote,
  });
}
