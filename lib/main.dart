import 'package:flutter/material.dart';

import 'repo.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/index_service.dart';
import 'storage.dart';

void main() => runApp(const DocBookApp());

class DocBookApp extends StatelessWidget {
  const DocBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocBook',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const _Bootstrap(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E3A5F),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surfaceContainerLow,
      ),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Future<RepoConfig?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RepoConfig?> _load() async {
    final saved = await Storage.read();
    if (saved == null) return null;
    return RepoConfig(
      owner: saved.owner,
      name: saved.name,
      branch: saved.branch,
    );
  }

  void _onConfigured(RepoConfig cfg) {
    setState(() {
      _future = Future.value(cfg);
    });
  }

  void _onCleared() {
    setState(() {
      _future = Future.value(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoConfig?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final cfg = snap.data;
        if (cfg == null) {
          return SetupScreen(onConfigured: _onConfigured);
        }
        return HomeScreen(
          config: cfg,
          service: IndexService(cfg),
          onCleared: _onCleared,
          onChanged: _onConfigured,
        );
      },
    );
  }
}
