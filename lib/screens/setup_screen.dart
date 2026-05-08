import 'package:flutter/material.dart';

import '../repo.dart';
import '../storage.dart';

class SetupScreen extends StatefulWidget {
  final void Function(RepoConfig) onConfigured;
  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // No prefilled owner — keep this generic so the app feels neutral.
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cfg = await RepoConfig.resolve(_ctrl.text);
      if (!mounted) return;
      if (cfg == null) {
        setState(() {
          _error = "Couldn't resolve that repo. Check the URL or owner/name.";
        });
        return;
      }
      await Storage.write(
        owner: cfg.owner,
        name: cfg.name,
        branch: cfg.branch,
      );
      widget.onConfigured(cfg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.45) ?? cs.primary],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to DocBook',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Point me at a Git repo of Markdown books.\nI will render them on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _ctrl,
                enabled: !_busy,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'GitHub repo',
                  hintText: 'e.g. your-org/your-book',
                  prefixIcon: const Icon(Icons.cloud_outlined),
                  errorText: _error,
                ),
                onSubmitted: (_) => _busy ? null : _connect(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Examples',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ExampleRow(text: 'your-org/your-book'),
                    _ExampleRow(text: 'https://github.com/your-org/your-book'),
                    _ExampleRow(text: 'git@github.com:your-org/your-book.git'),
                    _ExampleRow(text: 'your-org/your-book@main'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(_busy ? 'Connecting…' : 'Connect'),
              ),
              const Spacer(),
              Text(
                'You can change the repo any time from Settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  final String text;
  const _ExampleRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '• ',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
