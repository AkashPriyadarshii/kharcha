import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/capture_inbox.dart';
import '../data/sync_engine.dart';
import '../data/transaction_repository.dart';
import 'quick_add_dialog.dart';
import 'tabs/budget_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/transactions_tab.dart';

/// Main shell: tabbed navigation (Home / Transactions / Budget). Drains the
/// UPI inbox on startup (captures expenses added while closed) and syncs.
/// Reports (4.3) and Profile (4.5) land in later steps — no placeholder tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.container});

  /// The app-level Riverpod container (the shell is not under a default
  /// ProviderScope, so sync uses this one to read providers).
  final ProviderContainer container;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _drainInbox();
    // Auto-backup: flush any dirty rows every 30s while the app is open, so a
    // budget/edit made a minute ago reaches Supabase without waiting for a
    // trigger. Offline failures no-op (rows stay dirty, retried next tick).
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_drainInbox());
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _drainInbox() async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await drainCaptureInbox(inbox: await captureInboxFile(), repo: repo);
      // Newly captured expenses are dirty → flush them to Supabase.
      await syncIfSignedIn(widget.container);
    } catch (_) {
      // Opportunistic; never block the shell on a capture failure.
    }
  }

  Future<void> _signOut(BuildContext context) async {
    authBypass.value = false; // also exit guest mode
    await Supabase.instance.client.auth.signOut();
    // Router redirects to /auth on session change.
  }

  void _quickAdd(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const QuickAddDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kharcha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add expense',
            onPressed: () => context.push('/add'),
          ),
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Auto-capture UPI payments',
              onPressed: () => context.push('/enable-capture'),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _quickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          HomeTab(),
          TransactionsTab(),
          BudgetTab(),
          ReportsTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
