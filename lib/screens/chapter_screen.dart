import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/book_index.dart';
import '../services/index_service.dart';

/// Reader screen.
///
/// Each chapter is one horizontal page in a [PageView]. Within a chapter the
/// content scrolls vertically. We pre-fetch the previous/next chapter so the
/// swipe is instant.
class ChapterScreen extends StatefulWidget {
  final Book book;
  final IndexService service;
  final int initialIndex;

  const ChapterScreen({
    super.key,
    required this.book,
    required this.service,
    required this.initialIndex,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late final PageController _pageController;
  late int _index;
  late List<ChapterRef> _flat;
  // chapter-index -> Future<String> body
  final Map<int, Future<String>> _bodies = {};
  // user-controlled font size factor
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _flat = widget.book.flatChapters;
    _index = widget.initialIndex.clamp(0, _flat.length - 1);
    _pageController = PageController(initialPage: _index);
    _ensureLoaded(_index);
    _prefetchNeighbors();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _ensureLoaded(int i) {
    if (i < 0 || i >= _flat.length) return;
    _bodies.putIfAbsent(i, () async {
      final ref = _flat[i];
      final repoPath = widget.book.resolvePath(ref.chapter.path);
      return widget.service.loadMarkdown(repoPath);
    });
  }

  void _prefetchNeighbors() {
    if (_index - 1 >= 0) _ensureLoaded(_index - 1);
    if (_index + 1 < _flat.length) _ensureLoaded(_index + 1);
  }

  void _onPage(int i) {
    setState(() {
      _index = i;
    });
    _prefetchNeighbors();
  }

  Future<void> _animateTo(int i) async {
    if (i < 0 || i >= _flat.length) return;
    await _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _changeFont() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reader settings',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 16),
              Text('Font size · ${(_scale * 100).round()}%',
                  style: Theme.of(ctx).textTheme.labelLarge),
              Slider(
                value: _scale,
                min: 0.85,
                max: 1.5,
                divisions: 13,
                activeColor: cs.primary,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() {
                    _scale = v;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _flat[_index];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.book.shortTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              ref.part.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reader settings',
            onPressed: _changeFont,
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgressBar(
            index: _index,
            total: _flat.length,
            accent: widget.book.accentColor,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _flat.length,
              onPageChanged: _onPage,
              itemBuilder: (ctx, i) {
                _ensureLoaded(i);
                return _ChapterPage(
                  ref: _flat[i],
                  bodyFuture: _bodies[i]!,
                  scale: _scale,
                  accent: widget.book.accentColor,
                  onRetry: () {
                    setState(() {
                      _bodies.remove(i);
                      _ensureLoaded(i);
                    });
                  },
                );
              },
            ),
          ),
          _ReaderNav(
            index: _index,
            total: _flat.length,
            accent: widget.book.accentColor,
            onPrev: _index > 0 ? () => _animateTo(_index - 1) : null,
            onNext: _index < _flat.length - 1
                ? () => _animateTo(_index + 1)
                : null,
            onJump: () => _showJumpSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showJumpSheet(BuildContext context) async {
    final accent = widget.book.accentColor;
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, sc) => ListView.separated(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          itemCount: _flat.length + 1,
          separatorBuilder: (_, idx) => const SizedBox(height: 4),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Jump to chapter',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              );
            }
            final idx = i - 1;
            final r = _flat[idx];
            final selected = idx == _index;
            return ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              selected: selected,
              selectedTileColor: accent.withValues(alpha: 0.10),
              leading: CircleAvatar(
                backgroundColor:
                    selected ? accent : accent.withValues(alpha: 0.12),
                foregroundColor: selected ? Colors.white : accent,
                child: Text(
                  r.chapter.n.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                r.chapter.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : cs.onSurface,
                ),
              ),
              subtitle: Text(
                '${r.part.title.replaceAll('Part ', 'P')} · ${r.chapter.minutes} min',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _animateTo(idx);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChapterPage extends StatelessWidget {
  final ChapterRef ref;
  final Future<String> bodyFuture;
  final double scale;
  final Color accent;
  final VoidCallback onRetry;

  const _ChapterPage({
    required this.ref,
    required this.bodyFuture,
    required this.scale,
    required this.accent,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: bodyFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 56, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Could not load this chapter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${snap.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return _RenderedMarkdown(
          ref: ref,
          body: snap.data ?? '',
          scale: scale,
          accent: accent,
        );
      },
    );
  }
}

class _RenderedMarkdown extends StatelessWidget {
  final ChapterRef ref;
  final String body;
  final double scale;
  final Color accent;

  const _RenderedMarkdown({
    required this.ref,
    required this.body,
    required this.scale,
    required this.accent,
  });

  /// Strip the chapter's redundant heading + bottom-of-page nav block. The
  /// app provides better navigation chrome, so the textual links only add
  /// noise inside the reader.
  String _clean(String src) {
    var out = src;
    // Remove leading "# Chapter N — Title" so we don't double up the title.
    out = out.replaceFirst(
      RegExp(r'^\s*#\s+Chapter\s+\d+.*?\n+', multiLine: true),
      '',
    );
    // Strip horizontal-rule + nav-block we add to chapters
    final navRe = RegExp(
      r'\n*\s*-{3,}\s*\n+\s*\*\*\[(?:← Previous|Up|Next).*?$',
      multiLine: true,
      dotAll: true,
    );
    out = out.replaceAll(navRe, '');
    return out.trimRight();
  }

  void _onTapLink(BuildContext context, String text, String? href, String title) {
    if (href == null || href.isEmpty) return;
    if (href.startsWith('http://') || href.startsWith('https://')) {
      final uri = Uri.tryParse(href);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Internal navigation is handled by the page navigation; in-text links to
    // sibling chapters are intentionally a no-op here so the reader stays
    // linear. Users use the bottom nav / chapter sheet to jump.
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cleanBody = _clean(body);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = Theme.of(context).textTheme;
    final scaled = base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: (base.bodyLarge?.fontSize ?? 16) * scale,
        height: 1.6,
        letterSpacing: 0.1,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: (base.bodyMedium?.fontSize ?? 14) * scale,
        height: 1.55,
      ),
    );

    final styleSheet =
        MarkdownStyleSheet.fromTheme(Theme.of(context).copyWith(
      textTheme: scaled,
    )).copyWith(
      h1: TextStyle(
        fontSize: 24 * scale,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: cs.onSurface,
      ),
      h2: TextStyle(
        fontSize: 21 * scale,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: cs.onSurface,
      ),
      h3: TextStyle(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      h4: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      p: TextStyle(
        fontSize: 16 * scale,
        height: 1.65,
        letterSpacing: 0.1,
        color: cs.onSurface,
      ),
      listBullet: TextStyle(
        fontSize: 16 * scale,
        color: cs.onSurface,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      blockquote: TextStyle(
        fontSize: 15.5 * scale,
        color: cs.onSurface,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
      // Code styling — high contrast in both themes.
      // flutter_markdown reuses this `code` TextStyle for inline AND for
      // text inside a code block, so we deliberately do not set a
      // backgroundColor here (it would bleed inside the block container).
      // Inline `code` is distinguished by color + monospace + weight.
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14.5 * scale,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: isDark
            ? const Color(0xFFE6EDF3) // near-white for code blocks on dark
            : const Color(0xFF24292F), // near-black for light
      ),
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1117) // GitHub dark code bg
            : const Color(0xFFF6F8FA), // GitHub light code bg
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF30363D)
              : const Color(0xFFD0D7DE),
        ),
      ),
      tableHead: TextStyle(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
        fontSize: 14 * scale,
      ),
      tableBody: TextStyle(
        fontSize: 14 * scale,
        color: cs.onSurface,
        height: 1.4,
      ),
      tableBorder: TableBorder(
        horizontalInside:
            BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5), width: 1),
        top: BorderSide(color: cs.outlineVariant, width: 1),
        bottom: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      a: TextStyle(
        color: accent,
        decoration: TextDecoration.underline,
        decorationColor: accent.withValues(alpha: 0.5),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
      children: [
        _ChapterHeader(ref: ref, accent: accent, scale: scale),
        const SizedBox(height: 20),
        MarkdownBody(
          data: cleanBody,
          selectable: true,
          shrinkWrap: true,
          softLineBreak: true,
          styleSheet: styleSheet,
          onTapLink: (t, h, title) => _onTapLink(context, t, h, title),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  final ChapterRef ref;
  final Color accent;
  final double scale;
  const _ChapterHeader({
    required this.ref,
    required this.accent,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chapter ${ref.chapter.n}',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 12 * scale,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ref.chapter.title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 30 * scale,
            height: 1.15,
            color: cs.onSurface,
            letterSpacing: -0.4,
          ),
        ),
        if (ref.chapter.subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            ref.chapter.subtitle,
            style: TextStyle(
              fontSize: 16 * scale,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.schedule_outlined,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${ref.chapter.minutes} min read',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ref.part.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.0)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int index;
  final int total;
  final Color accent;
  const _ProgressBar({
    required this.index,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total <= 1 ? 1.0 : (index + 1) / total;
    return Container(
      height: 3,
      color: cs.surfaceContainerHigh,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(color: accent),
        ),
      ),
    );
  }
}

class _ReaderNav extends StatelessWidget {
  final int index;
  final int total;
  final Color accent;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onJump;

  const _ReaderNav({
    required this.index,
    required this.total,
    required this.accent,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.arrow_back_rounded,
              label: 'Prev',
              onTap: onPrev,
            ),
            Expanded(
              child: InkWell(
                onTap: onJump,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          ' / $total',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.expand_less_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _NavButton(
              icon: Icons.arrow_forward_rounded,
              label: 'Next',
              onTap: onNext,
              forward: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool forward;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.forward = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onTap == null ? cs.outline : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: forward
              ? [
                  Text(label,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(icon, size: 18, color: color),
                ]
              : [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                ],
        ),
      ),
    );
  }
}
