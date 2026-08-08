import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_lock.dart';
import '../../data/exporter.dart';
import '../../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Profile: account, payment methods, export, backup status, settings, app lock.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodTotalsProvider);
    final sync = ref.watch(syncStatusProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AccountHeader(),
        const SizedBox(height: 24),
        Text('Payment methods', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (methods.value == null)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (methods.value!.isEmpty)
          Text('No transactions yet.', style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final (method, amount, _) in methods.value!)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(method[0].toUpperCase() + method.substring(1)),
              trailing: Text(
                _currency.format(amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        const SizedBox(height: 16),
        Text('Backup & export', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (sync.value != null)
          Text(
            'Synced ${sync.value!.$1} of ${sync.value!.$1 + sync.value!.$2} expenses',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _export(context, ref, csv: true),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _export(context, ref, csv: false),
                icon: const Icon(Icons.code),
                label: const Text('JSON'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        _AppLockTile(),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool csv}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = await (csv
          ? Exporter(ref.read(transactionRepositoryProvider)).exportCsv(dir, 'kharcha_$stamp.csv')
          : Exporter(ref.read(transactionRepositoryProvider)).exportJson(dir, 'kharcha_$stamp.json'));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Signed in';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: user?.userMetadata?['name'] != null
                  ? Text((user!.userMetadata!['name'] as String).substring(0, 1).toUpperCase())
                  : const Icon(Icons.person),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.userMetadata?['name'] as String? ?? 'Kharcha user',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  const _AppLockTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appLockControllerProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('App lock'),
      subtitle: const Text('Biometric / PIN on every open'),
      value: enabled,
      onChanged: (v) async {
        final ok = await ref.read(appLockControllerProvider.notifier).setEnabled(v);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No biometric or PIN set up on this device.')),
          );
        }
      },
    );
  }
}
