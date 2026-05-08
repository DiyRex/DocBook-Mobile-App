import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book_index.dart';
import '../repo.dart';
import 'markdown_cache.dart';

/// Fetches and caches the repo's index.json + chapter markdown bodies.
/// One service instance per logged-in repo (rebuilt when settings change).
class IndexService {
  final RepoConfig config;
  final RepoService _repo;
  final MarkdownCache _cache;
  final Duration indexTtl;

  BookIndex? _cachedIndex;
  DateTime? _indexFetchedAt;

  // 10 MB in-memory cap. A chapter is ~30 KB markdown, so this comfortably
  // holds ~300 chapters — far more than any single reading session re-visits.
  // The cache is RAM-only, freed when the OS evicts the app or the user
  // force-closes; we don't write to disk, so there is no persistent storage
  // footprint.
  IndexService(
    this.config, {
    int maxCacheBytes = 10 * 1024 * 1024,
    this.indexTtl = const Duration(minutes: 10),
  })  : _repo = RepoService(config),
        _cache = MarkdownCache(maxBytes: maxCacheBytes);

  int get cacheCapacityBytes => _cache.maxBytes;

  bool get _indexFresh =>
      _cachedIndex != null &&
      _indexFetchedAt != null &&
      DateTime.now().difference(_indexFetchedAt!) < indexTtl;

  Future<BookIndex> loadIndex({bool force = false}) async {
    if (!force && _indexFresh) return _cachedIndex!;
    final url = Uri.parse('${config.rawBase()}index.json');
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      // Fall back to a stale copy if we have one and the fetch failed.
      if (_cachedIndex != null) return _cachedIndex!;
      throw Exception(
          'No index.json at ${config.displayUrl()} (HTTP ${res.statusCode}). '
          'Add an index.json at the repo root, or use a repo that has one.');
    }
    final j = json.decode(res.body) as Map<String, dynamic>;
    _cachedIndex = BookIndex.fromJson(j);
    _indexFetchedAt = DateTime.now();
    return _cachedIndex!;
  }

  /// Fetch a markdown file at a repo-relative path. Cached by path with
  /// LRU + byte-cap eviction.
  Future<String> loadMarkdown(String repoPath) async {
    final hit = _cache.get(repoPath);
    if (hit != null) return hit;
    final body = await _repo.fetchMarkdown(repoPath);
    _cache.put(repoPath, body);
    return body;
  }

  /// Pre-fetch (best-effort, no error propagation) a chapter so the
  /// next/prev page is instant when the user swipes.
  Future<void> prefetchMarkdown(String repoPath) async {
    if (_cache.contains(repoPath)) return;
    try {
      final body = await _repo.fetchMarkdown(repoPath);
      _cache.put(repoPath, body);
    } catch (_) {/* swallow */}
  }

  // --- Cache introspection / control (used by Settings) ---

  int get cachedBytes => _cache.sizeBytes;
  int get cachedEntries => _cache.entryCount;

  void clearCache() {
    _cache.clear();
    _cachedIndex = null;
    _indexFetchedAt = null;
  }
}
