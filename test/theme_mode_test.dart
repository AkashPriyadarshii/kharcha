import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/theme_mode.dart';

void main() {
  group('ThemeModeStore', () {
    test('round-trips a mode', () async {
      final dir = await Directory.systemTemp.createTemp('theme_mode_test');
      addTearDown(() => dir.delete(recursive: true));
      final store = ThemeModeStore(File('${dir.path}/theme_mode.json'));

      expect(await store.load(), ThemeMode.system); // missing → system

      await store.save(ThemeMode.dark);
      expect(await store.load(), ThemeMode.dark);

      await store.save(ThemeMode.light);
      expect(await store.load(), ThemeMode.light);
    });

    test('corrupt file → system (not a crash)', () async {
      final dir = await Directory.systemTemp.createTemp('theme_mode_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/theme_mode.json');
      await file.writeAsString('not json');
      expect(await ThemeModeStore(file).load(), ThemeMode.system);
    });
  });

  group('ThemeModeController', () {
    test('set persists and updates state', () async {
      final dir = await Directory.systemTemp.createTemp('theme_mode_test');
      addTearDown(() => dir.delete(recursive: true));
      final store = ThemeModeStore(File('${dir.path}/theme_mode.json'));
      final controller = ThemeModeController(store: store);

      expect(controller.state, ThemeMode.system);
      await controller.set(ThemeMode.dark);
      expect(controller.state, ThemeMode.dark);
      expect(await store.load(), ThemeMode.dark); // persisted, reloadable
    });
  });
}
