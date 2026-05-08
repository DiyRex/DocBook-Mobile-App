import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _kOwner = 'repo.owner';
  static const _kName = 'repo.name';
  static const _kBranch = 'repo.branch';

  static Future<({String owner, String name, String branch})?> read() async {
    final p = await SharedPreferences.getInstance();
    final o = p.getString(_kOwner);
    final n = p.getString(_kName);
    final b = p.getString(_kBranch);
    if (o == null || n == null || b == null) return null;
    return (owner: o, name: n, branch: b);
  }

  static Future<void> write({
    required String owner,
    required String name,
    required String branch,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOwner, owner);
    await p.setString(_kName, name);
    await p.setString(_kBranch, branch);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOwner);
    await p.remove(_kName);
    await p.remove(_kBranch);
  }
}
