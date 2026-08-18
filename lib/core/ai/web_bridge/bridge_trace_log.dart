// A-01: BridgeTraceLog — Fixed circular buffer for diagnostic events
import 'dart:collection';

enum BridgeTraceLevel { info, warn, error }

class BridgeTraceEntry {
  const BridgeTraceEntry({
    required this.at,
    required this.type,
    required this.source,
    this.requestId,
    this.textLength,
    this.note,
    this.level = BridgeTraceLevel.info,
  });

  final DateTime at;
  final String type;
  final String source;
  final String? requestId;
  final int? textLength;
  final String? note;
  final BridgeTraceLevel level;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'type': type,
    'source': source,
    if (requestId != null) 'requestId': requestId,
    if (textLength != null) 'textLength': textLength,
    if (note != null) 'note': note,
    'level': level.name,
  };

  @override
  String toString() {
    final timeStr =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}.${at.millisecond.toString().padLeft(3, '0')}';
    final req = requestId != null ? ' req=$requestId' : '';
    final len = textLength != null ? ' len=$textLength' : '';
    final nt = note != null ? ' note="$note"' : '';
    return '[$timeStr] [${level.name.toUpperCase()}] type=$type src=$source$req$len$nt';
  }
}

class BridgeTraceLog {
  BridgeTraceLog._();
  static final BridgeTraceLog instance = BridgeTraceLog._();

  static const int maxEntries = 300;
  final ListQueue<BridgeTraceEntry> _entries = ListQueue<BridgeTraceEntry>(maxEntries);

  List<BridgeTraceEntry> get entries => List.unmodifiable(_entries);

  void add(BridgeTraceEntry entry) {
    if (_entries.length >= maxEntries) {
      _entries.removeFirst();
    }
    _entries.addLast(entry);
  }

  void addEntry({
    required String type,
    required String source,
    String? requestId,
    int? textLength,
    String? note,
    BridgeTraceLevel level = BridgeTraceLevel.info,
    DateTime? at,
  }) {
    add(
      BridgeTraceEntry(
        at: at ?? DateTime.now(),
        type: type,
        source: source,
        requestId: requestId,
        textLength: textLength,
        note: note,
        level: level,
      ),
    );
  }

  void clear() {
    _entries.clear();
  }

  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== RITMO CHATGPT WEB BRIDGE TRACE LOG ===');
    buffer.writeln('Total Entries: ${_entries.length}');
    buffer.writeln('Exported At: ${DateTime.now().toIso8601String()}');
    buffer.writeln('------------------------------------------');
    for (final entry in _entries) {
      buffer.writeln(entry.toString());
    }
    buffer.writeln('==========================================');
    return buffer.toString();
  }
}
