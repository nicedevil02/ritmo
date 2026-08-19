import 'dart:convert';

/// مدل گونهٔ فعالیت حرکتی
class MovementActivityKind {
  const MovementActivityKind({
    required this.id,
    required this.nameFa,
    this.nameEn,
    this.aliases = const [],
    required this.family,
    required this.icon,
    required this.primaryMetric,
    this.defaultUnits = const [],
    this.isCustom = false,
    this.isFavorite = false,
    this.archivedAt,
    required this.createdAt,
  });

  final String id;
  final String nameFa;
  final String? nameEn;
  final List<String> aliases;
  final String family;
  final String icon;
  final String primaryMetric;
  final List<String> defaultUnits;
  final bool isCustom;
  final bool isFavorite;
  final DateTime? archivedAt;
  final DateTime createdAt;

  factory MovementActivityKind.fromMap(Map<String, dynamic> map) {
    List<String> parseJsonList(dynamic val) {
      if (val == null) return const [];
      if (val is List) return val.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return const [];
    }

    return MovementActivityKind(
      id: map['id'] as String,
      nameFa: map['nameFa'] as String,
      nameEn: map['nameEn'] as String?,
      aliases: parseJsonList(map['aliasesJson']),
      family: map['family'] as String? ?? 'walking',
      icon: map['icon'] as String? ?? 'directions_walk',
      primaryMetric: map['primaryMetric'] as String? ?? 'duration',
      defaultUnits: parseJsonList(map['defaultUnitsJson']),
      isCustom: (map['isCustom'] as int? ?? 0) == 1,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      archivedAt: map['archivedAt'] != null
          ? DateTime.tryParse(map['archivedAt'].toString())
          : null,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  MovementActivityKind copyWith({
    String? id,
    String? nameFa,
    String? nameEn,
    List<String>? aliases,
    String? family,
    String? icon,
    String? primaryMetric,
    List<String>? defaultUnits,
    bool? isCustom,
    bool? isFavorite,
    DateTime? archivedAt,
    DateTime? createdAt,
  }) {
    return MovementActivityKind(
      id: id ?? this.id,
      nameFa: nameFa ?? this.nameFa,
      nameEn: nameEn ?? this.nameEn,
      aliases: aliases ?? this.aliases,
      family: family ?? this.family,
      icon: icon ?? this.icon,
      primaryMetric: primaryMetric ?? this.primaryMetric,
      defaultUnits: defaultUnits ?? this.defaultUnits,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (nameFa.toLowerCase().contains(q)) return true;
    if (nameEn?.toLowerCase().contains(q) == true) return true;
    if (family.toLowerCase().contains(q)) return true;
    return aliases.any((a) => a.toLowerCase().contains(q));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameFa': nameFa,
      'nameEn': nameEn,
      'aliasesJson': jsonEncode(aliases),
      'family': family,
      'icon': icon,
      'primaryMetric': primaryMetric,
      'defaultUnitsJson': jsonEncode(defaultUnits),
      'isCustom': isCustom ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'archivedAt': archivedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
