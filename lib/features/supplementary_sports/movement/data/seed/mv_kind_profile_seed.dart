import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:sqflite/sqflite.dart';

/// Seed data for `mv_kind_profile` (S3-T1).
class MvKindProfileSeed {
  static const Map<String, Map<String, dynamic>> explicitProfiles = {
    'FOOTBALL': {
      'primaryMuscles': 'hamstrings,quads,calves,glutes',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'posterior_chain,adductors,ankle',
      'prehabTags': 'nordic_hamstring,copenhagen,ankle_hop',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'FUTSAL': {
      'primaryMuscles': 'hamstrings,quads,calves,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'posterior_chain,adductors,ankle',
      'prehabTags': 'nordic_hamstring,copenhagen,ankle_hop',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'BASKETBALL': {
      'primaryMuscles': 'quads,calves,glutes,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'landing,knee,hip',
      'prehabTags': 'lateral_bound,nordic,copenhagen',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'VOLLEYBALL': {
      'primaryMuscles': 'calves,quads,shoulders,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'landing,rotator_cuff,calf',
      'prehabTags': 'drop_squat,band_external_rotation,calf_raise',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'TENNIS': {
      'primaryMuscles': 'shoulders,forearm,quads,core',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'rotator_cuff,thoracic,hip',
      'prehabTags': 'band_external_rotation,thoracic_rotation',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'BADMINTON': {
      'primaryMuscles': 'calves,shoulders,quads',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'ankle,rotator_cuff,hip',
      'prehabTags': 'ankle_hop,band_external_rotation',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'SQUASH': {
      'primaryMuscles': 'quads,calves,shoulders',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'ankle,hip,rotator_cuff',
      'prehabTags': 'lateral_bound,ankle_hop',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'TABLE_TENNIS': {
      'primaryMuscles': 'forearm,shoulders,core',
      'neuroCost': 1,
      'recoveryHours': 12,
      'complementFocus': 'thoracic,wrist',
      'prehabTags': 'wrist_curl,thoracic_rotation',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'HIKING': {
      'primaryMuscles': 'quads,glutes,calves,erector',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'step_up,carry,eccentric_quad',
      'prehabTags': 'step_down_eccentric,farmer_carry,tibialis_raise',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'ROCK_CLIMBING': {
      'primaryMuscles': 'forearm,lats,biceps,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'antagonist_push,scapular,wrist',
      'prehabTags': 'band_press,scapular_pullup,wrist_extension',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'RUNNING': {
      'primaryMuscles': 'calves,hamstrings,quads',
      'neuroCost': 2,
      'recoveryHours': 24,
      'complementFocus': 'posterior_chain,hip_stability',
      'prehabTags': 'calf_raise,single_leg_bridge',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'TRAIL_RUNNING': {
      'primaryMuscles': 'calves,quads,glutes,ankle',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'ankle,eccentric_quad,hip',
      'prehabTags': 'step_down_eccentric,ankle_hop',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'CYCLING': {
      'primaryMuscles': 'quads,glutes,calves',
      'neuroCost': 1,
      'recoveryHours': 24,
      'complementFocus': 'posterior_chain,core,thoracic',
      'prehabTags': 'hip_hinge,thoracic_extension',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'SWIMMING': {
      'primaryMuscles': 'lats,shoulders,core',
      'neuroCost': 1,
      'recoveryHours': 12,
      'complementFocus': 'thoracic,scapular,hip',
      'prehabTags': 'scapular_retraction,thoracic_rotation',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'JUMP_ROPE': {
      'primaryMuscles': 'calves,quads,shoulders',
      'neuroCost': 2,
      'recoveryHours': 24,
      'complementFocus': 'ankle,calf',
      'prehabTags': 'calf_raise,ankle_hop',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'KARATE': {
      'primaryMuscles': 'hips,core,shoulders',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'hip_mobility,core,neck',
      'prehabTags': 'hip_flexor_stretch,dead_bug',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'TAEKWONDO': {
      'primaryMuscles': 'hips,hamstrings,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'hip_mobility,hamstring,core',
      'prehabTags': 'hip_flexor_stretch,hamstring_curl',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'JUDO': {
      'primaryMuscles': 'back,grip,core,hips',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'grip,posterior_chain,neck',
      'prehabTags': 'farmer_carry,neck_isometric',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'WRESTLING': {
      'primaryMuscles': 'back,grip,neck,hips',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'grip,neck,posterior_chain',
      'prehabTags': 'farmer_carry,neck_isometric',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'BOXING': {
      'primaryMuscles': 'shoulders,core,calves',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'rotator_cuff,core,neck',
      'prehabTags': 'band_external_rotation,dead_bug',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'YOGA': {
      'primaryMuscles': 'full_body',
      'neuroCost': 1,
      'recoveryHours': 0,
      'complementFocus': 'none',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'STRETCHING': {
      'primaryMuscles': 'full_body',
      'neuroCost': 1,
      'recoveryHours': 0,
      'complementFocus': 'none',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'WALKING': {
      'primaryMuscles': 'calves,glutes',
      'neuroCost': 1,
      'recoveryHours': 0,
      'complementFocus': 'none',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'SKIING': {
      'primaryMuscles': 'quads,glutes,core',
      'neuroCost': 3,
      'recoveryHours': 48,
      'complementFocus': 'eccentric_quad,ankle,core',
      'prehabTags': 'wall_sit,step_down_eccentric',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'BODYWEIGHT': {
      'primaryMuscles': 'full_body',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'mobility,core',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'STRENGTH_HOME': {
      'primaryMuscles': 'full_body',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'mobility,core',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
    'STRENGTH_GYM': {
      'primaryMuscles': 'full_body',
      'neuroCost': 2,
      'recoveryHours': 36,
      'complementFocus': 'mobility,core',
      'prehabTags': 'none',
      'recommendedTierBefore': 'light',
      'recommendedTierAfter': 'light',
    },
  };

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mv_kind_profile (
        kindCode              TEXT PRIMARY KEY,
        primaryMuscles        TEXT NOT NULL,
        neuroCost             INTEGER NOT NULL,
        recoveryHours         INTEGER NOT NULL,
        complementFocus       TEXT NOT NULL,
        prehabTags            TEXT,
        recommendedTierBefore TEXT NOT NULL,
        recommendedTierAfter  TEXT NOT NULL
      );
    ''');
  }

  static Future<void> ensureSeed(DatabaseExecutor db) async {
    await ensureSchema(db);

    // Retrieve all active kinds from movement_kinds
    var rows = await db.query(
      'movement_kinds',
      columns: ['code', 'jointImpact'],
    );

    if (rows.isEmpty) {
      await MovementKindsSeed.seed(db);
      rows = await db.query(
        'movement_kinds',
        columns: ['code', 'jointImpact'],
      );
    }

    final batch = db.batch();

    for (final row in rows) {
      final code = row['code'] as String;
      final jointImpact = (row['jointImpact'] as num?)?.toInt() ?? 1;

      if (explicitProfiles.containsKey(code)) {
        final profile = explicitProfiles[code]!;
        batch.insert(
          'mv_kind_profile',
          {
            'kindCode': code,
            'primaryMuscles': profile['primaryMuscles'],
            'neuroCost': profile['neuroCost'],
            'recoveryHours': profile['recoveryHours'],
            'complementFocus': profile['complementFocus'],
            'prehabTags': profile['prehabTags'],
            'recommendedTierBefore': profile['recommendedTierBefore'],
            'recommendedTierAfter': profile['recommendedTierAfter'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Default fallback profile calculation (S3-T1 specification)
        final int neuroCost = jointImpact >= 3
            ? 3
            : (jointImpact == 2 ? 2 : 1);
        final int recoveryHours = jointImpact * 16;

        batch.insert(
          'mv_kind_profile',
          {
            'kindCode': code,
            'primaryMuscles': 'full_body',
            'neuroCost': neuroCost,
            'recoveryHours': recoveryHours,
            'complementFocus': 'mobility,core',
            'prehabTags': null,
            'recommendedTierBefore': 'light',
            'recommendedTierAfter': 'light',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
  }
}
