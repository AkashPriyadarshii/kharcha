import '../core/app_logger.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/update_checker.dart';
import '../data/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ponytail: whole-APK download (~26MB), no delta. Play Store publish
/// supersedes this whole path — swap for `in_app_update` then.
/// Rate caps: 1 auto-check/day, 60 manual checks/hour. GitHub's unauth limit
/// is 60/hr per IP, so 1000 users never flag the account — 429 just fails
/// silent and retries next time.

/// Auto-check once per app open (network check throttled to 1/hour). 
/// Silent unless a newer release with a real APK asset exists.
Future<void> checkForUpdate(BuildContext context) async {
  // Network throttle: never hit GitHub API more than once an hour automatically
  // (GitHub unauthenticated rate limit is 60/hr per IP).
  final lastChk = await _lastChecked();
  if (lastChk != null &&
      DateTime.now().difference(lastChk) < const Duration(hours: 1)) {
    return;
  }
  await _recordCheck();

  String versionName;
  try {
    versionName = await const MethodChannel('com.kharcha.app/update')
            .invokeMethod<String>('getVersion') ??
        '0.0.0';
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    versionName = '0.0.0';
  }

  final info = await fetchLatestRelease(versionName: versionName);
  if (info == null || !info.available || info.apkUrl == null) return; // silent
  if (!context.mounted) return;

  // Prompt throttle: never prompt the user more than once a day.
  final lastPrompt = await _lastPrompted();
  if (lastPrompt != null &&
      DateTime.now().difference(lastPrompt) < const Duration(hours: 24)) {
    return;
  }
  if (!context.mounted) return;

  // Show a silent persistent notification so they can update from the tray later.
  try {
    final notif = ProviderScope.containerOf(context).read(notificationsProvider);
    notif.showUpdateAvailable(versionTag: info.tag!);
  } catch (e) {
    // Ignore if provider is unavailable
  }

  await _promptAndInstall(context, info);
}

/// Manual "Check for updates" from Profile. Same flow, but capped at 60/hour
/// (user-initiated, so it skips the daily gate — hitting the cap shows a
/// snackbar rather than silently doing nothing).
Future<void> manualCheckForUpdate(BuildContext context) async {
  final recent = await _recentManualChecks();
  recent.retainWhere(
      (t) => DateTime.now().difference(t) < const Duration(hours: 1));
  if (recent.length >= 3) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'ve checked recently — try again in an hour.')),
      );
    }
    return;
  }
  await _recordManualCheck();

  String versionName;
  try {
    versionName = await const MethodChannel('com.kharcha.app/update')
            .invokeMethod<String>('getVersion') ??
        '0.0.0';
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    versionName = '0.0.0';
  }
  final info = await fetchLatestRelease(versionName: versionName);
  if (info == null || !info.available || info.apkUrl == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'re on the latest version.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await _promptAndInstall(context, info);
}

Future<void> _promptAndInstall(BuildContext context, UpdateInfo info) async {
  await recordPrompt(); // Throttle regardless of user choice — without this,
  // dismissing with "Not now" meant no record, re-prompted every app open.
  if (!context.mounted) return;
  final doUpdate = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update available'),
      content: Text('Kharcha ${info.tag ?? ''} is ready. Download now?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update'),
        ),
      ],
    ),
  );
  if (doUpdate != true) return;

  final ok = await _downloadAndInstall(info.apkUrl!, info.apkSize!);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update failed — try again later.')),
    );
  }
}

/// Downloads to `cache/kharcha-update.apk`, size-checks it, then hands off to
/// the OS installer. Returns false on any failure (corrupt / size mismatch).
Future<bool> _downloadAndInstall(String url, int expectedSize) async {
  final cacheDir = await getTemporaryDirectory(); // getCacheDir() on Android
  final apk = File('${cacheDir.path}/kharcha-update.apk');
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url))
      ..headers.set('User-Agent', 'Kharcha-updater');
    final res = await req.close();
    if (res.statusCode != 200) return false;
    final sink = apk.openWrite();
    await res.pipe(sink); // streamed — no RAM blowup on 26MB
    await sink.close();
    if (await apk.length() != expectedSize) {
      await apk.delete(); // truncated/corrupt — never hand a bad APK to the installer
      return false;
    }
    await const MethodChannel('com.kharcha.app/update')
        .invokeMethod<void>('installApk', {'path': apk.path});
    return true;
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    try {
      await apk.delete();
    } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);}
    return false;
  } finally {
    client.close(force: true);
  }
}

// ---- throttle state (device-local JSON) ----
Future<File> get _checkFile async => File(
    '${(await getApplicationDocumentsDirectory()).path}/update_last_checked.json');

Future<DateTime?> _lastChecked() async {
  try {
    final f = await _checkFile;
    if (!await f.exists()) return null;
    return DateTime.tryParse(await f.readAsString());
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    return null;
  }
}

Future<void> _recordCheck() async {
  try {
    await (await _checkFile).writeAsString(DateTime.now().toIso8601String());
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);}
}

Future<File> get _promptFile async => File(
    '${(await getApplicationDocumentsDirectory()).path}/update_last_prompted.json');

Future<DateTime?> _lastPrompted() async {
  try {
    final f = await _promptFile;
    if (!await f.exists()) return null;
    return DateTime.tryParse(await f.readAsString());
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    return null;
  }
}

Future<void> recordPrompt() async {
  try {
    await (await _promptFile).writeAsString(DateTime.now().toIso8601String());
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);}
}

Future<File> get _manualFile async => File(
    '${(await getApplicationDocumentsDirectory()).path}/update_manual_checks.json');

/// Timestamps of recent manual checks (for the 3/hr cap).
Future<List<DateTime>> _recentManualChecks() async {
  try {
    final f = await _manualFile;
    if (!await f.exists()) return [];
    final list = (jsonDecode(await f.readAsString()) as List)
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
    return list;
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);
    return [];
  }
}

Future<void> _recordManualCheck() async {
  try {
    final f = await _manualFile;
    final recent = (await _recentManualChecks())
        .where((t) => DateTime.now().difference(t) < const Duration(hours: 1))
        .toList()
      ..add(DateTime.now());
    await f.writeAsString(jsonEncode(
      recent.map((t) => t.toIso8601String()).toList(),
    ));
  } catch (e, st) {
    AppLogger().e('App', 'Exception caught', e, st);}
}
