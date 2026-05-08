import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as one_dark;
import 'package:flutter_highlight/themes/github.dart' as gh_light;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../models/book_index.dart';
import '../services/index_service.dart';

/// Reader screen.
///
/// Each chapter is one horizontal page in a [PageView]. Within a chapter the
/// content scrolls vertically inside a *lazy* [Markdown] (which renders one
/// block per ListView entry) so we don't pay to materialize the entire
/// chapter on swipe.
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
      duration: const Duration(milliseconds: 320),
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
              physics: const PageScrollPhysics(),
              itemBuilder: (ctx, i) {
                _ensureLoaded(i);
                return _ChapterPage(
                  key: ValueKey('chapter-$i'),
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
    super.key,
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
                Icon(Icons.cloud_off_outlined, size: 56, color: cs.error),
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
        return _RenderedChapter(
          ref: ref,
          body: snap.data ?? '',
          scale: scale,
          accent: accent,
        );
      },
    );
  }
}

/// Stateful so we can memoize the cleaned markdown body and the style sheet —
/// both are invariant per (body, scale, accent, brightness) and recomputing
/// them on every parent rebuild was hundreds of allocations of overhead.
class _RenderedChapter extends StatefulWidget {
  final ChapterRef ref;
  final String body;
  final double scale;
  final Color accent;

  const _RenderedChapter({
    required this.ref,
    required this.body,
    required this.scale,
    required this.accent,
  });

  @override
  State<_RenderedChapter> createState() => _RenderedChapterState();
}

class _RenderedChapterState extends State<_RenderedChapter> {
  late String _cleanedBody;
  MarkdownStyleSheet? _styleSheet;
  Brightness? _styleSheetBrightness;
  double? _styleSheetScale;
  // Memoized code-block builder (rebuilt only when scale or brightness changes)
  Map<String, MarkdownElementBuilder>? _builders;

  @override
  void initState() {
    super.initState();
    _cleanedBody = _clean(widget.body);
  }

  @override
  void didUpdateWidget(covariant _RenderedChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.body != oldWidget.body) {
      _cleanedBody = _clean(widget.body);
    }
  }

  /// Strip the chapter's redundant heading + bottom-of-page nav block. The
  /// app provides better navigation chrome, so the textual links only add
  /// noise inside the reader.
  static String _clean(String src) {
    var out = src;
    out = out.replaceFirst(
      RegExp(r'^\s*#\s+Chapter\s+\d+.*?\n+', multiLine: true),
      '',
    );
    final navRe = RegExp(
      r'\n*\s*-{3,}\s*\n+\s*\*\*\[(?:← Previous|Up|Next).*?$',
      multiLine: true,
      dotAll: true,
    );
    out = out.replaceAll(navRe, '');
    return out.trimRight();
  }

  void _onTapLink(String text, String? href, String title) {
    if (href == null || href.isEmpty) return;
    if (href.startsWith('http://') || href.startsWith('https://')) {
      final uri = Uri.tryParse(href);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Internal/relative links inside the body intentionally no-op:
    // the reader navigates linearly via the bottom prev/next + jump sheet.
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final scale = widget.scale;
    final accent = widget.accent;

    final base = theme.textTheme;
    return MarkdownStyleSheet.fromTheme(theme.copyWith(
      textTheme: base.copyWith(
        bodyLarge: base.bodyLarge?.copyWith(
          fontSize: (base.bodyLarge?.fontSize ?? 16) * scale,
          height: 1.6,
          letterSpacing: 0.1,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontSize: (base.bodyMedium?.fontSize ?? 14) * scale,
          height: 1.55,
        ),
      ),
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
      // High-contrast code styling. We intentionally do NOT set a
      // backgroundColor on `code:` because flutter_markdown reuses this
      // TextStyle for both inline `code` and the text inside a fenced block,
      // which would bleed inside the codeblockDecoration container.
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14.5 * scale,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: isDark
            ? const Color(0xFFE6EDF3) // GitHub dark code text
            : const Color(0xFF24292F), // GitHub light code text
      ),
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF6F8FA),
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
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Memoize: only rebuild stylesheet when scale or brightness changes.
    if (_styleSheet == null ||
        _styleSheetBrightness != theme.brightness ||
        _styleSheetScale != widget.scale) {
      _styleSheet = _buildStyleSheet(context);
      _styleSheetBrightness = theme.brightness;
      _styleSheetScale = widget.scale;
      _builders = {
        'code': _CodeElementBuilder(
          isDark: theme.brightness == Brightness.dark,
          scale: widget.scale,
        ),
      };
    }

    return Column(
      children: [
        _CompactChapterHeader(ref: widget.ref, accent: widget.accent),
        Expanded(
          // The scrollable Markdown widget builds blocks lazily, so we never
          // materialize the entire ~8 KB chapter at once.
          child: Markdown(
            data: _cleanedBody,
            // Disable text selection — adds a SelectionRegistrar per block,
            // which is a real cost on long chapters and was producing the
            // "Skipped 286 frames!" reports during PageView swipes.
            selectable: false,
            softLineBreak: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
            styleSheet: _styleSheet,
            onTapLink: _onTapLink,
            builders: _builders ?? const {},
          ),
        ),
      ],
    );
  }
}

/// Compact, sticky-style header shown above the scrolling content. Replaces
/// the older big in-content hero — that lived inside the same scroll list
/// which forced eager layout of the whole chapter when it was a ListView.
class _CompactChapterHeader extends StatelessWidget {
  final ChapterRef ref;
  final Color accent;
  const _CompactChapterHeader({required this.ref, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CH ${ref.chapter.n}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.schedule_outlined,
                  size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${ref.chapter.minutes} min',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ref.chapter.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
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

/// Renders fenced code blocks with VSCode-style syntax highlighting via
/// `flutter_highlight`. Inline `` `code` `` falls through to the default
/// rendering (returning null from [visitElementAfter]) so it picks up the
/// stylesheet's `code:` TextStyle.
class _CodeElementBuilder extends MarkdownElementBuilder {
  final bool isDark;
  final double scale;

  _CodeElementBuilder({required this.isDark, required this.scale});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    final cls = element.attributes['class'] ?? '';
    // Fenced blocks always carry "language-XYZ" or contain a newline. Inline
    // `code` is a single line with no class — render with the default style.
    final isBlock = cls.startsWith('language-') || text.contains('\n');
    if (!isBlock) return null;

    final lang = cls.startsWith('language-')
        ? cls.substring('language-'.length)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1117) // GitHub dark
            : const Color(0xFFF6F8FA), // GitHub light
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF30363D)
              : const Color(0xFFD0D7DE),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang != null && lang.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.fromLTRB(14, 8, 14, 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF21262D)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Text(
                lang.toUpperCase(),
                style: TextStyle(
                  fontSize: 10 * scale,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFF7D8590)
                      : const Color(0xFF6E7781),
                ),
              ),
            ),
          // Horizontal scroll for long code lines so we never wrap, which
          // would mangle indentation. The HighlightView itself uses the
          // VSCode-like theme (atom-one-dark / github).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            child: HighlightView(
              text,
              language: lang,
              theme: isDark ? one_dark.atomOneDarkTheme : gh_light.githubTheme,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13.5 * scale,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
