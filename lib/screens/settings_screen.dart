import 'package:flutter/material.dart';

import '../repo.dart';
import '../services/index_service.dart';
import '../storage.dart';

class SettingsScreen extends StatefulWidget {
  final RepoConfig config;
  final IndexService service;
  final void Function() onCleared;
  final void Function(RepoConfig) onChanged;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.service,
    required this.onCleared,
    required this.onChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _ctrl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.config.displayUrl());
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cfg = await RepoConfig.resolve(_ctrl.text);
      if (!mounted) return;
      if (cfg == null) {
        setState(() => _error = "Couldn't resolve that repo.");
        return;
      }
      await Storage.write(
        owner: cfg.owner,
        name: cfg.name,
        branch: cfg.branch,
      );
      widget.onChanged(cfg);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetToSetup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset?'),
        content: const Text(
            'This clears the saved repo and returns you to the setup screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    await Storage.clear();
    if (!mounted) return;
    widget.onCleared();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _clearCache() {
    setState(() {
      widget.service.clearCache();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _SectionLabel('Repository'),
          TextField(
            controller: _ctrl,
            enabled: !_busy,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'GitHub repo',
              hintText: 'OWNER/REPO  or  https://github.com/OWNER/REPO',
              prefixIcon: const Icon(Icons.cloud_outlined),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Currently: ${widget.config.displayUrl()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
          const SizedBox(height: 32),
          _SectionLabel('Cache'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'In-memory cache',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _CacheStat(
                      label: 'Cached',
                      value: '${widget.service.cachedEntries}',
                    ),
                    const SizedBox(width: 24),
                    _CacheStat(
                      label: 'Size',
                      value: _humanBytes(widget.service.cachedBytes),
                    ),
                    const SizedBox(width: 24),
                    _CacheStat(
                      label: 'Cap',
                      value: _humanBytes(widget.service.cacheCapacityBytes),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'In-memory only — uses no disk space. Chapters are cached as you read; oldest evicted first when the cap is reached. Cleared automatically when you switch repos or close the app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear cache now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _SectionLabel('Danger zone'),
          OutlinedButton.icon(
            onPressed: _busy ? null : _resetToSetup,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset to setup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 32),
          _SectionLabel('About'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'DocBook',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Renders Markdown books from any GitHub repo with an index.json at the root. Adding a new book is documented in AUTHORING.md in the repo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _CacheStat extends StatelessWidget {
  final String label;
  final String value;
  const _CacheStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
        ),
      ],
    );
  }
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
