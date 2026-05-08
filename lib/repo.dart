/// Repository URL handling and raw-fetch logic.
///
/// We accept several user-friendly forms of repo URL and normalize to a base
/// raw URL we can append paths to:
///
///   git@github.com:DiyRex/DocBook.git
///   https://github.com/DiyRex/DocBook
///   https://github.com/DiyRex/DocBook.git
///   DiyRex/DocBook
///
///                   --->  https://raw.githubusercontent.com/DiyRex/DocBook/main/
library;

import 'package:http/http.dart' as http;

class RepoConfig {
  final String owner;
  final String name;
  final String branch;
  const RepoConfig({required this.owner, required this.name, required this.branch});

  String rawBase() =>
      'https://raw.githubusercontent.com/$owner/$name/$branch/';

  String webBase() => 'https://github.com/$owner/$name/blob/$branch/';

  String displayUrl() => 'github.com/$owner/$name@$branch';

  /// Try common branch names to find one that has a README.md.
  static Future<RepoConfig?> resolve(String input) async {
    final parsed = _parse(input);
    if (parsed == null) return null;
    final (owner, name, branchHint) = parsed;
    final branches = branchHint != null ? [branchHint] : ['main', 'master'];
    for (final b in branches) {
      final cfg = RepoConfig(owner: owner, name: name, branch: b);
      try {
        final res = await http
            .head(Uri.parse('${cfg.rawBase()}README.md'))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) return cfg;
      } catch (_) {/* try next */}
    }
    return null;
  }

  static (String, String, String?)? _parse(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    // Strip a trailing ".git"
    if (s.endsWith('.git')) s = s.substring(0, s.length - 4);

    // git@github.com:OWNER/REPO
    final ssh = RegExp(r'^git@github\.com:([^/]+)/([^/]+)$');
    var m = ssh.firstMatch(s);
    if (m != null) return (m.group(1)!, m.group(2)!, null);

    // https://github.com/OWNER/REPO  (optionally /tree/BRANCH)
    final https = RegExp(
        r'^https?://github\.com/([^/]+)/([^/]+?)(?:/tree/([^/]+))?$');
    m = https.firstMatch(s);
    if (m != null) return (m.group(1)!, m.group(2)!, m.group(3));

    // OWNER/REPO  (optionally @BRANCH)
    final shortBranch = RegExp(r'^([^/\s]+)/([^/\s@]+)@([^/\s]+)$');
    m = shortBranch.firstMatch(s);
    if (m != null) return (m.group(1)!, m.group(2)!, m.group(3));

    final short = RegExp(r'^([^/\s]+)/([^/\s]+)$');
    m = short.firstMatch(s);
    if (m != null) return (m.group(1)!, m.group(2)!, null);

    return null;
  }
}

class RepoService {
  final RepoConfig config;
  RepoService(this.config);

  /// Fetch a Markdown file at a path relative to the repo root.
  /// If the path ends with "/" we treat it as a directory and append README.md.
  /// If the path has no extension we also try appending README.md and "/README.md".
  Future<String> fetchMarkdown(String repoPath) async {
    final candidates = _candidates(repoPath);
    Object? lastError;
    for (final p in candidates) {
      final url = Uri.parse('${config.rawBase()}$p');
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) return res.body;
        lastError = 'HTTP ${res.statusCode} for $p';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Could not fetch $repoPath ($lastError)');
  }

  List<String> _candidates(String p) {
    var path = p;
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.isEmpty) return ['README.md'];
    if (path.endsWith('/')) return ['${path}README.md'];

    final last = path.split('/').last;
    if (last.contains('.')) return [path];

    // No extension: assume it might be a directory or a file we've abbreviated.
    return ['$path/README.md', '$path.md', path];
  }
}
