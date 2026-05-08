import 'package:flutter/material.dart';

import '../models/book_index.dart';
import '../services/index_service.dart';
import '../widgets/chapter_tile.dart';
import 'chapter_screen.dart';

class BookScreen extends StatelessWidget {
  final Book book;
  final IndexService service;

  const BookScreen({super.key, required this.book, required this.service});

  void _openChapter(BuildContext context, int flatIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterScreen(
          book: book,
          service: service,
          initialIndex: flatIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = book.accentColor;
    final flat = book.flatChapters;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: _Cover(book: book, accent: accent),
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
              title: Text(
                book.shortTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                  ),
                  if (book.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      book.subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: book.tags
                        .map((t) => _Chip(label: t, accent: accent))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    book.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: flat.isEmpty
                              ? null
                              : () => _openChapter(context, 0),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(flat.isEmpty
                              ? 'No chapters'
                              : 'Start reading · ${flat.first.chapter.title}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Stats(book: book, accent: accent),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          for (int pi = 0; pi < book.parts.length; pi++)
            _PartSliver(
              book: book,
              part: book.parts[pi],
              accent: accent,
              partIndex: pi,
              onTapChapter: _openChapter,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Book book;
  final Color accent;
  const _Cover({required this.book, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent,
                Color.lerp(accent, Colors.black, 0.55) ?? accent,
              ],
            ),
          ),
        ),
        // Decorative corner accent
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          right: 40,
          top: 60,
          child: Icon(
            Icons.menu_book_rounded,
            color: Colors.white.withValues(alpha: 0.18),
            size: 140,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color accent;
  const _Chip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final Book book;
  final Color accent;
  const _Stats({required this.book, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Parts',
            value: book.parts.length.toString(),
            accent: accent,
          ),
          _Divider(),
          _Stat(
            label: 'Chapters',
            value: book.totalChapters.toString(),
            accent: accent,
          ),
          _Divider(),
          _Stat(
            label: 'Read time',
            value: _hours(book.totalMinutes),
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _Stat(
      {required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

String _hours(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class _PartSliver extends StatelessWidget {
  final Book book;
  final Part part;
  final Color accent;
  final int partIndex;
  final void Function(BuildContext, int) onTapChapter;

  const _PartSliver({
    required this.book,
    required this.part,
    required this.accent,
    required this.partIndex,
    required this.onTapChapter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Compute the flat-chapter offset for this part.
    var startFlat = 0;
    for (int p = 0; p < partIndex; p++) {
      startFlat += book.parts[p].chapters.length;
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      sliver: SliverList.list(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                ),
                if (part.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    part.summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${part.chapters.length} chapters · ${_hours(part.totalMinutes)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                for (int i = 0; i < part.chapters.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ChapterTile(
                    chapter: part.chapters[i],
                    accent: accent,
                    onTap: () => onTapChapter(context, startFlat + i),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
