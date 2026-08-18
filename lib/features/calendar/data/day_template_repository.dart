import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class DayTemplateSlot {
  const DayTemplateSlot({
    required this.title,
    required this.timeOfDay,
    required this.durationMinutes,
    this.domainName,
    this.kindName,
    this.categoryName,
    this.sourceId,
  });

  final String title;
  final String timeOfDay;
  final int durationMinutes;
  final String? domainName;
  final String? kindName;
  final String? categoryName;
  final String? sourceId;

  Map<String, dynamic> toMap() => {
    'title': title,
    'timeOfDay': timeOfDay,
    'durationMinutes': durationMinutes,
    'domainName': domainName,
    'kindName': kindName,
    'categoryName': categoryName,
    'sourceId': sourceId,
  };

  factory DayTemplateSlot.fromMap(Map<String, dynamic> map) => DayTemplateSlot(
    title: map['title'] as String? ?? '',
    timeOfDay: map['timeOfDay'] as String? ?? '08:00',
    durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
    domainName: map['domainName'] as String?,
    kindName: map['kindName'] as String?,
    categoryName: map['categoryName'] as String?,
    sourceId: map['sourceId'] as String?,
  );
}

class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.name,
    required this.slots,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<DayTemplateSlot> slots;
  final DateTime createdAt;

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'name': name,
    'payloadJson': jsonEncode(slots.map((s) => s.toMap()).toList()),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory DayTemplate.fromDbMap(Map<String, dynamic> map) {
    final payloadStr = map['payloadJson'] as String? ?? '[]';
    final rawList = (jsonDecode(payloadStr) as List<dynamic>?) ?? [];
    final slots = rawList
        .whereType<Map<String, dynamic>>()
        .map(DayTemplateSlot.fromMap)
        .toList();
    return DayTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      slots: slots,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class DayTemplateRepository {
  DayTemplateRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<void> saveTemplate(DayTemplate template) async {
    final db = await _dbHelper.database;
    await db.insert(
      'day_templates',
      template.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DayTemplate>> getAllTemplates() async {
    final db = await _dbHelper.database;
    final rows = await db.query('day_templates', orderBy: 'createdAt DESC');
    return rows.map(DayTemplate.fromDbMap).toList();
  }

  Future<void> deleteTemplate(String id) async {
    final db = await _dbHelper.database;
    await db.delete('day_templates', where: 'id = ?', whereArgs: [id]);
  }
}
