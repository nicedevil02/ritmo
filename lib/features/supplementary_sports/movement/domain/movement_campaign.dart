// lib/features/supplementary_sports/movement/domain/movement_campaign.dart

import 'dart:convert';

enum MovementCampaignStatus {
  active('ACTIVE'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const MovementCampaignStatus(this.code);
  final String code;

  static MovementCampaignStatus fromCode(String code) {
    return MovementCampaignStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => MovementCampaignStatus.active,
    );
  }
}

class MovementCampaign {
  const MovementCampaign({
    required this.id,
    required this.titleFa,
    required this.goalCode,
    required this.startDate,
    required this.weeks,
    required this.status,
    required this.routineIds,
    this.progressJson,
  });

  final String id;
  final String titleFa;
  final String goalCode;
  final String startDate; // yyyy-MM-dd
  final int weeks;
  final MovementCampaignStatus status;
  final List<String> routineIds;
  final String? progressJson;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titleFa': titleFa,
      'goalCode': goalCode,
      'startDate': startDate,
      'weeks': weeks,
      'status': status.code,
      'routineIds': jsonEncode(routineIds),
      'progressJson': progressJson,
    };
  }

  factory MovementCampaign.fromMap(Map<String, dynamic> map) {
    List<String> rIds = [];
    try {
      final decoded = jsonDecode(map['routineIds']?.toString() ?? '[]');
      if (decoded is List) {
        rIds = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return MovementCampaign(
      id: map['id'] as String,
      titleFa: map['titleFa'] as String,
      goalCode: map['goalCode'] as String,
      startDate: map['startDate'] as String,
      weeks: (map['weeks'] as num).toInt(),
      status: MovementCampaignStatus.fromCode(map['status']?.toString() ?? 'ACTIVE'),
      routineIds: rIds,
      progressJson: map['progressJson'] as String?,
    );
  }
}
