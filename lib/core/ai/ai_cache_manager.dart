import 'dart:convert';

class AICacheEntry {
  AICacheEntry(this.response, this.expireTime);
  final Map<String, dynamic> response;
  final DateTime expireTime;

  bool get isExpired => DateTime.now().isAfter(expireTime);
}

class AICacheManager {
  AICacheManager._init();
  static final AICacheManager instance = AICacheManager._init();
  final Map<String, AICacheEntry> _cacheStore = {};
  static const int _maxEntries = 100;

  String _buildKey(String query, Map<String, dynamic> context) {
    final sortedKeys = context.keys.toList()..sort();
    final canonicalMap = <String, dynamic>{};
    for (final k in sortedKeys) {
      canonicalMap[k] = context[k];
    }
    String contextStr;
    try {
      contextStr = jsonEncode(canonicalMap);
    } catch (_) {
      contextStr = canonicalMap.toString();
    }
    return '${query.trim()}_$contextStr';
  }

  Map<String, dynamic>? get(String query, Map<String, dynamic> context) {
    final key = _buildKey(query, context);
    final entry = _cacheStore[key];
    if (entry != null) {
      if (!entry.isExpired) {
        // Move to most recently used (LRU)
        _cacheStore.remove(key);
        _cacheStore[key] = entry;
        return entry.response;
      } else {
        _cacheStore.remove(key);
      }
    }
    return null;
  }

  void set(
    String query,
    Map<String, dynamic> context,
    Map<String, dynamic> response, {
    int ttlMinutes = 10,
  }) {
    final key = _buildKey(query, context);
    final expireTime = DateTime.now().add(Duration(minutes: ttlMinutes));

    if (_cacheStore.length >= _maxEntries) {
      final oldestKey = _cacheStore.keys.first;
      _cacheStore.remove(oldestKey);
    }

    _cacheStore[key] = AICacheEntry(response, expireTime);
  }

  void clear() {
    _cacheStore.clear();
  }
}

