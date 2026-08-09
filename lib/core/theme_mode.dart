import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the selected [ThemeMode]. Plain JSON file in app documents —
/// same pattern as AppLockStore. Missing/corrupt → system default.
class ThemeModeStore {
  ThemeModeStore(this.file);

  final File file;

  static Future<ThemeModeStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return ThemeModeStore(File('${dir.path}/theme_mode.json'));
  }

  Future<ThemeMode> load() async {
    try {
      if (!await file.exists()) return ThemeMode.system;
      return ThemeMode.values.byName(jsonDecode(await file.readAsString()) as String);
    } catch (_) {
      return ThemeMode.system; // missing/corrupt → follow the OS.
    }
  }

  Future<void> save(ThemeMode mode) =>
      file.writeAsString(jsonEncode(mode.name), flush: true);
}

/// Which theme the app uses: follow the OS, or force light/dark.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) => ThemeModeController());

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController({ThemeModeStore? store}) : _store = store, super(ThemeMode.system);

  final ThemeModeStore? _store;

  Future<ThemeModeStore> get _stores async => _store ?? await ThemeModeStore.create();

  /// Loads the persisted mode. Safe to call once at startup.
  Future<void> load() async => state = await (await _stores).load();

  /// Sets and persists the mode.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    await (await _stores).save(mode);
  }
}
