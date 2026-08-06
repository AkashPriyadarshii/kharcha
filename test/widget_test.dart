import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharcha/core/config.dart';

void main() {
  test('config exposes Supabase url', () {
    expect(SupabaseConfig.url, contains('supabase.co'));
    expect(SupabaseConfig.anonKey, isNotEmpty);
  });

  testWidgets('app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Kharcha'))));
    expect(find.text('Kharcha'), findsOneWidget);
  });
}
