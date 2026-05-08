/// Bounded in-memory LRU cache for chapter markdown bodies.
///
/// Capped by approximate UTF-16 byte size (str.length * 2). Default 100 MB —
/// in practice this is a "don't leak forever" guard rather than active
/// management; a 30 KB chapter × 3,000 chapters fits comfortably.
///
/// Recency: re-insertion of a key on read moves it to the most-recent slot.
library;

import 'dart:collection';

class MarkdownCache {
  final int maxBytes;
  final LinkedHashMap<String, String> _store = LinkedHashMap();
  int _bytes = 0;

  MarkdownCache({this.maxBytes = 10 * 1024 * 1024});

  String? get(String key) {
    final v = _store.remove(key);
    if (v == null) return null;
    // Reinsert as most-recent.
    _store[key] = v;
    return v;
  }

  void put(String key, String value) {
    final size = value.length * 2; // UTF-16 chars
    if (size > maxBytes) {
      // A single value larger than cap; refuse to cache rather than wipe.
      return;
    }
    final existing = _store.remove(key);
    if (existing != null) _bytes -= existing.length * 2;
    _store[key] = value;
    _bytes += size;
    while (_bytes > maxBytes && _store.isNotEmpty) {
      final oldestKey = _store.keys.first;
      final oldest = _store.remove(oldestKey);
      if (oldest != null) _bytes -= oldest.length * 2;
    }
  }

  bool contains(String key) => _store.containsKey(key);

  /// Approximate cached size in bytes (UTF-16).
  int get sizeBytes => _bytes;

  int get entryCount => _store.length;

  void clear() {
    _store.clear();
    _bytes = 0;
  }
}
