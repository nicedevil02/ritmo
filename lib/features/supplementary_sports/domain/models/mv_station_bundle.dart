/// Station Bundle Model (`station_bundles`).
/// Follows N-09 & F-31.
class MvStationBundle {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String itemsJson;
  final bool isUserTemplate;
  final int usageCount;
  final int createdAt;
  final int updatedAt;

  const MvStationBundle({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.itemsJson,
    this.isUserTemplate = false,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'itemsJson': itemsJson,
      'isUserTemplate': isUserTemplate ? 1 : 0,
      'usageCount': usageCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MvStationBundle.fromMap(Map<String, dynamic> map) {
    return MvStationBundle(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: (map['category'] as String?) ?? 'general',
      itemsJson: (map['itemsJson'] as String?) ?? '[]',
      isUserTemplate: (map['isUserTemplate'] as num?)?.toInt() == 1,
      usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
