import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/app_lock.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/notifications.dart';
import 'data/sync_engine.dart';
import 'data/transaction_repository.dart';
import 'screens/add_expense_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/bill_splitter_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/enable_capture_screen.dart';
import 'screens/home_shell.dart';
import 'screens/objectives_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/wallets_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  await _container.read(appLockControllerProvider.notifier).load();
  onboardingDone.value = await (await OnboardingStore.create()).isDone();
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

class KharchaApp extends ConsumerWidget {
  const KharchaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kharcha',
      theme: kharchaTheme(),
      routerConfig: _router,
      // LockGate overlays everything while the app is locked.
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shows a full-screen lock when app lock is enabled and the app is
/// foregrounded; unlocks via OS biometric/PIN prompt on demand.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock on every foreground — returning to the app re-prompts.
    if (state == AppLifecycleState.resumed) setState(() => _unlocked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _unlock() async {
    final ok = await ref.read(appLockControllerProvider.notifier).unlock();
    if (ok && mounted) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockControllerProvider);
    if (!enabled || _unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text('Kharcha is locked', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _container = ProviderContainer();

final _router = GoRouter(
  refreshListenable: Listenable.merge([
    _AuthRefresh(Supabase.instance.client.auth.onAuthStateChange),
    authBypass,
    onboardingDone,
  ]),
  redirect: (context, state) {
    final loggedIn = authBypass.value ||
        Supabase.instance.client.auth.currentSession != null;
    final atAuth = state.matchedLocation == '/auth';
    if (!loggedIn && !atAuth) return '/auth';
    if (loggedIn && atAuth) return '/';
    // Signed in → run onboarding once, before the home shell.
    if (loggedIn && state.matchedLocation == '/' && !onboardingDone.value) {
      return '/onboarding';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/', builder: (context, state) => HomeShell(container: _container)),
    GoRoute(
      path: '/add',
      builder: (context, state) =>
          AddExpenseScreen(transaction: state.extra as Transaction?),
    ),
    GoRoute(path: '/enable-capture', builder: (context, state) => const EnableCaptureScreen()),
    GoRoute(path: '/wallets', builder: (context, state) => const WalletsScreen()),
    GoRoute(path: '/subscriptions', builder: (context, state) => const SubscriptionsScreen()),
    GoRoute(path: '/objectives', builder: (context, state) => const ObjectivesScreen()),
    GoRoute(path: '/split', builder: (context, state) => const BillSplitterScreen()),
    GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
    GoRoute(path: '/debts', builder: (context, state) => const DebtsScreen()),

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
