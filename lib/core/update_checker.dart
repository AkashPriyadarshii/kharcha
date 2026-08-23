import 'dart:convert';
import 'dart:io';

/// Fetches the latest GitHub release and decides whether an update exists.
///
/// ponytail: update source is GitHub releases, forever. If the app ever
/// publishes on Play Store, this whole checker is superseded by
/// `in_app_update` — swap then.
class UpdateInfo {
  const UpdateInfo({required this.available, this.tag, this.apkUrl, this.apkSize});

  final bool available;
  final String? tag;
  final String? apkUrl;
  final int? apkSize;
}

/// True when `a` is strictly newer than `b` (semver, numeric, not string).
/// Strips a leading `v` and any pre-release suffix (`-beta`) before comparing.
bool compareVersions(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i] > pb[i];
  }
  return false; // equal → not newer
}

List<int> _parse(String v) {
  final core = v.trim().replaceFirst(RegExp('^v'), '').split('-').first;
  final parts = core.split('.');
  return List.generate(3, (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0);
}

/// The release APK asset for this repo. Must exist on the release before the
/// update is offered — a version bump with no uploaded APK never prompts.
const _assetName = 'kharcha-armv8a-release.apk';

/// Checks for an update against the GitHub releases API. Returns null when the
/// check failed (offline / 429 / malformed) — callers must stay silent on null.
Future<UpdateInfo?> fetchLatestRelease({
  String versionName = '0.0.0',
  HttpClient? client,
}) async {
  final c = client ?? HttpClient();
  try {
    final req = await c
        .getUrl(Uri.parse('https://api.github.com/repos/AkashPriyadarshii/kharcha/releases/latest'))
      ..headers.set('User-Agent', 'Kharcha/$versionName')
      ..headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close();
    if (res.statusCode != 200) return null; // 404 (no release) or 429 → silent
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tag = json['tag_name'] as String?;
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final apk = assets
        .where((a) => (a['name'] == _assetName || a['name'] == 'app-arm64-v8a-release.apk') && 
                      a['size'] is int && 
                      a['size'] != 0)
        .firstOrNull;
    if (tag == null || apk == null) return const UpdateInfo(available: false);
    final available = compareVersions(tag, versionName);
    return UpdateInfo(
      available: available,
      tag: tag,
      apkUrl: apk['browser_download_url'] as String?,
      apkSize: apk['size'] as int,
    );
  } catch (_) {
    return null; // network / parse failure → silent
  } finally {
    c.close(force: true);
  }
}
