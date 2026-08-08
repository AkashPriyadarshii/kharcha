import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_lock.dart';
import '../../core/theme.dart';
import '../../data/exporter.dart';
import '../../data/importer.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _AccountHeader(),
        const SizedBox(height: 24),
        const SectionTitle('Payment methods'),
        const SizedBox(height: 8),
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
        const SectionTitle('Backup & export'),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _import(context, ref),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Import CSV'),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Settings'),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.balance),
          title: const Text('Credit & debt'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/debts'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.category_outlined),
          title: const Text('Categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/categories'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Wallets'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/wallets'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.repeat),
          title: const Text('Subscriptions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/subscriptions'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Savings goals'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/objectives'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.call_split),
          title: const Text('Split a bill'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/split'),
        ),
        _AppLockTile(),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool csv}) async {
    try {
      // Always land in the user's Downloads folder (Android scoped storage
      // gives it without any permission on API 29+).
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
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

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return; // user cancelled

      final repo = ref.read(transactionRepositoryProvider);
      final result = await importCsv(File(path), repo);
      if (!context.mounted) return;
      final msg = result.errors.isEmpty
          ? 'Imported ${result.added} expenses.'
          : 'Imported ${result.added}, skipped ${result.skipped}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}

class _AccountHeader extends ConsumerStatefulWidget {
  const _AccountHeader();

  @override
  ConsumerState<_AccountHeader> createState() => _AccountHeaderState();
}

class _AccountHeaderState extends ConsumerState<_AccountHeader> {
  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.userMetadata?['name'] as String? ?? 'Kharcha user',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit name',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editName(context),
                      ),
                    ],
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

  /// Inline name editor — persists to Supabase so it syncs across devices.
  Future<void> _editName(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final controller = TextEditingController(
      text: user.userMetadata?['name'] as String? ?? '',
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await Supabase.instance.client.auth.updateUser(UserAttributes(
      data: {...user.userMetadata ?? const {}, 'name': newName},
    ));
    if (context.mounted) setState(() {});
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
