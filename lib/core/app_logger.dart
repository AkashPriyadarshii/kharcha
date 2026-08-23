import 'dart:collection';
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

  void e(String module, String event, [dynamic error, StackTrace? st]) {
    log(module, event, level: 'ERROR', payload: {'error': error?.toString(), 'stack': st?.toString()});
  }
}
