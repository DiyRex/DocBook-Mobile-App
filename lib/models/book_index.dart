/// Strongly-typed model of the repo's `index.json`.
///
/// The JSON schema is intentionally small and human-editable. See the repo's
/// index.json for the canonical example.
library;

import 'package:flutter/material.dart';

class BookIndex {
  final int schema;
  final String title;
  final String tagline;
  final List<Book> books;

  const BookIndex({
    required this.schema,
    required this.title,
    required this.tagline,
    required this.books,
  });

  factory BookIndex.fromJson(Map<String, dynamic> j) => BookIndex(
        schema: (j['schema'] ?? 1) as int,
        title: (j['title'] ?? 'DocBook') as String,
        tagline: (j['tagline'] ?? '') as String,
        books: ((j['books'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Book.fromJson)
            .toList(growable: false),
      );
}

class Book {
  final String slug;
  final String title;
  final String shortTitle;
  final String subtitle;
  final String description;
  final List<String> tags;
  final Color accentColor;
  final String icon;
  final String status; // "in-progress" | "complete" | "draft"
  final String path; // repo-relative folder, e.g. "books/foo"
  final List<FrontmatterEntry> frontmatter;
  final List<Part> parts;

  const Book({
    required this.slug,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.description,
    required this.tags,
    required this.accentColor,
    required this.icon,
    required this.status,
    required this.path,
    required this.frontmatter,
    required this.parts,
  });

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        slug: j['slug'] as String,
        title: j['title'] as String,
        shortTitle: (j['shortTitle'] ?? j['title']) as String,
        subtitle: (j['subtitle'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        accentColor: _parseHexColor(j['accentColor'] as String? ?? '#1E3A5F'),
        icon: (j['icon'] ?? 'book') as String,
        status: (j['status'] ?? 'in-progress') as String,
        path: j['path'] as String,
        frontmatter: ((j['frontmatter'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FrontmatterEntry.fromJson)
            .toList(growable: false),
        parts: ((j['parts'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Part.fromJson)
            .toList(growable: false),
      );

  /// All chapters across parts, flattened, in reading order.
  List<ChapterRef> get flatChapters {
    final out = <ChapterRef>[];
    for (final p in parts) {
      for (final c in p.chapters) {
        out.add(ChapterRef(part: p, chapter: c));
      }
    }
    return out;
  }

  int get totalChapters => parts.fold(0, (a, p) => a + p.chapters.length);

  int get totalMinutes {
    var m = 0;
    for (final f in frontmatter) {
      m += f.minutes;
    }
    for (final p in parts) {
      for (final c in p.chapters) {
        m += c.minutes;
      }
    }
    return m;
  }

  /// Repo-relative path to a frontmatter or chapter document.
  String resolvePath(String relativeToBook) =>
      '$path/$relativeToBook';
}

class FrontmatterEntry {
  final String title;
  final String path;
  final int minutes;

  const FrontmatterEntry({
    required this.title,
    required this.path,
    required this.minutes,
  });

  factory FrontmatterEntry.fromJson(Map<String, dynamic> j) => FrontmatterEntry(
        title: j['title'] as String,
        path: j['path'] as String,
        minutes: (j['minutes'] ?? 0) as int,
      );
}

class Part {
  final String slug;
  final String title;
  final String summary;
  final List<Chapter> chapters;

  const Part({
    required this.slug,
    required this.title,
    required this.summary,
    required this.chapters,
  });

  factory Part.fromJson(Map<String, dynamic> j) => Part(
        slug: j['slug'] as String,
        title: j['title'] as String,
        summary: (j['summary'] ?? '') as String,
        chapters: ((j['chapters'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Chapter.fromJson)
            .toList(growable: false),
      );

  int get totalMinutes => chapters.fold(0, (a, c) => a + c.minutes);
}

class Chapter {
  final int n;
  final String title;
  final String subtitle;
  final String path; // book-relative path
  final int minutes;

  const Chapter({
    required this.n,
    required this.title,
    required this.subtitle,
    required this.path,
    required this.minutes,
  });

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        n: (j['n'] ?? 0) as int,
        title: j['title'] as String,
        subtitle: (j['subtitle'] ?? '') as String,
        path: j['path'] as String,
        minutes: (j['minutes'] ?? 0) as int,
      );
}

/// A flattened reference: which part the chapter belongs to + the chapter.
class ChapterRef {
  final Part part;
  final Chapter chapter;
  const ChapterRef({required this.part, required this.chapter});
}

Color _parseHexColor(String h) {
  var s = h.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  if (v == null) return const Color(0xFF1E3A5F);
  return Color(v);
}
