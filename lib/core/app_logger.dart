import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final _logs = ListQueue<String>(500);

  List<String> get logs => _logs.toList();

  void log(String module, String event, {String level = 'INFO', Map<String, dynamic>? payload}) {
    final timestamp = DateTime.now().toIso8601String();
    final payloadStr = payload != null ? payload.toString() : '';
    final logEntry = '[$timestamp] [$level] [$module] $event $payloadStr';
    
    if (_logs.length >= 500) {
      _logs.removeFirst();
    }
    _logs.addLast(logEntry);
    
    if (kDebugMode) {
      print(logEntry);
    }
  }

  
  Future<void> _reportError(String module, String event, dynamic error, StackTrace? st) async {
    try {
      final recentLogs = _logs.toList().reversed.take(50).toList();
      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'module': module,
        'event': event,
        'error': error?.toString(),
        'stack': st?.toString(),
        'trailing_logs': recentLogs,
      };
      
      try {
        await Supabase.instance.client.from('app_errors').insert(payload);
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/pending_crashes.jsonl');
        file.writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
      }
    } catch (_) {}
  }

  Future<void> flushPendingCrashes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_crashes.jsonl');
      if (!file.existsSync()) return;
      
      final lines = file.readAsLinesSync();
      if (lines.isEmpty) {
        file.deleteSync();
        return;
      }
      
      final client = Supabase.instance.client;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        await client.from('app_errors').insert(jsonDecode(line));
      }
      file.deleteSync();
    } catch (_) {}
  }

  void e(String module, String event, [dynamic error, StackTrace? st]) {
    log(module, event, level: 'ERROR', payload: {'error': error?.toString(), 'stack': st?.toString()});
    _reportError(module, event, error, st);
  }
}
