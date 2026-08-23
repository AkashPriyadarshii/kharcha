import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/capture_inbox.dart';
import '../data/notifications.dart';
import '../data/sync_engine.dart';
import '../data/transaction_repository.dart';
import 'quick_add_dialog.dart';
import 'update_dialog.dart';
import 'tabs/budget_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/transactions_tab.dart';

/// Controls active navigation tab across the app shell.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

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

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drainInbox();
    // Auto-backup: flush any dirty rows every 30s while the app is open, so a
    // budget/edit made a minute ago reaches Supabase without reaching a
    // trigger. Offline failures no-op (rows stay dirty, retried next tick).
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_drainInbox());
    });
    // Auto-update: check once per open, silent unless a real newer APK exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(checkForUpdate(context));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Drain captured transactions immediately when the user returns to the app.
    // Without this, payments made while backgrounded only appear on the next
    // 30s timer tick (if the timer survived Android battery optimization).
    if (state == AppLifecycleState.resumed) {
      unawaited(_drainInbox());
    }
  }

  bool _isDrainingInbox = false;

  Future<void> _drainInbox() async {
    if (_isDrainingInbox) return;
    _isDrainingInbox = true;
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final notif = ref.read(notificationsProvider);
      await drainCaptureInbox(
        inbox: await captureInboxFile(),
        repo: repo,
        notifications: notif,
      );
      // Newly captured expenses are dirty → flush them to Supabase.
      await syncIfSignedIn(widget.container);
    } catch (_) {
      // Opportunistic; never block the shell on a capture failure.
    } finally {
      _isDrainingInbox = false;
    }
  }

  void _quickAdd(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const QuickAddDialog());
  }

  /// Manage button: quick access to the "manage" screens (categories, wallets,
  /// subscriptions, goals, debts, split) without diving into Profile.
  void _openManage(BuildContext context) {
    const routes = [
      (Icons.category_outlined, 'Categories', '/categories'),
      (Icons.account_balance_wallet_outlined, 'Wallets', '/wallets'),
      (Icons.repeat, 'Subscriptions', '/subscriptions'),
      (Icons.flag_outlined, 'Savings goals', '/objectives'),
      (Icons.balance, 'Credit & debt', '/debts'),
      (Icons.call_split, 'Split a bill', '/split'),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, route) in routes)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(route);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabIndexProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kharcha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'Shortcuts & manage',
            onPressed: () => _openManage(context),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Secondary: quick-add dialog (fast, minimal fields)
          FloatingActionButton.small(
            heroTag: 'fab_quick',
            tooltip: 'Quick add',
            onPressed: () => _quickAdd(context),
            child: const Icon(Icons.bolt),
          ),
          const SizedBox(height: 12),
          // Primary: full add-expense form
          FloatingActionButton.extended(
            heroTag: 'fab_add',
            onPressed: () => context.push('/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [
          HomeTab(),
          TransactionsTab(),
          BudgetTab(),
          ReportsTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(homeTabIndexProvider.notifier).state = i,
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
