import 'package:flutter/foundation.dart';

/// Represents a distinct realm schedule configuration profile (e.g. Work Week, Vacation, Ramadan) (F-13).
@immutable
class ZoneProfile {
  const ZoneProfile({
    required this.id,
    required this.name,
    this.isActive = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final bool isActive;
  final int createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };

  factory ZoneProfile.fromMap(Map<String, dynamic> map) {
    return ZoneProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'پروفایل قلمرو',
      isActive: (map['isActive'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
    );
  }

  ZoneProfile copyWith({
    String? id,
    String? name,
    bool? isActive,
    int? createdAt,
  }) {
    return ZoneProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
