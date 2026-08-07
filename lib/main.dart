import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/config.dart';
import 'data/notifications.dart';
import 'data/sync_engine.dart';
import 'data/transaction_repository.dart';
import 'screens/add_expense_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/enable_capture_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  // Pull + push whenever a session appears (login / app resume with a session).
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.session != null) {
      unawaited(syncIfSignedIn(_container));
    }
  });
  _initNotifications();
  runApp(UncontrolledProviderScope(container: _container, child: const KharchaApp()));
}

/// Schedules the daily/weekly summaries. Never blocks startup or crashes the
/// app — notification setup is best-effort (permission can be denied).
Future<void> _initNotifications() async {
  try {
    final notifications =
        Notifications(FlutterLocalNotificationsPlugin(), _container.read(transactionRepositoryProvider));
    await notifications.init();
    await notifications.scheduleDaily();
    await notifications.scheduleWeekly();
  } catch (e) {
    debugPrint('notification setup skipped: $e');
  }
}

class KharchaApp extends StatelessWidget {
  const KharchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kharcha',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A6B4D), // ink green — ₹
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final _container = ProviderContainer();

final _router = GoRouter(
  refreshListenable: _AuthRefresh(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final atAuth = state.matchedLocation == '/auth';
    if (!loggedIn && !atAuth) return '/auth';
    if (loggedIn && atAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/', builder: (context, state) => HomeShell(container: _container)),
    GoRoute(path: '/add', builder: (context, state) => const AddExpenseScreen()),
    GoRoute(path: '/enable-capture', builder: (context, state) => const EnableCaptureScreen()),
  ],
);

/// Bridges Supabase auth changes into go_router's refreshListenable.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
