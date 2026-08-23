import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_lock.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/theme_mode.dart';
import '../../data/bug_reporter.dart';
import '../../data/exporter.dart';
import '../../data/importer.dart';
import '../../data/transaction_repository.dart';
import '../../widgets/income_expense_toggle.dart';
import '../update_dialog.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Where bug reports go. Email is the recommended channel (no account needed,
/// lands straight in the owner's inbox); the in-app path writes to Supabase.
const _supportEmail = 'akash.priyadarshi9100backup@gmail.com';

enum _ReportChannel { email, app }

/// The user's display name. Google sign-in stores it under `full_name`;
/// the in-app edit writes `name`. Check both.
String? _userName(User? user) {
  final meta = user?.userMetadata;
  if (meta == null) return null;
  return (meta['name'] as String?) ?? (meta['full_name'] as String?);
}

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
          onPressed: () => _export(context, ref, csv: true, anonymize: true),
          icon: const Icon(Icons.security),
          label: const Text('Privacy-First Export (Mask PII)'),
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
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Auto-capture setup'),
          subtitle: const Text('Re-run onboarding: capture, notifications, battery'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/onboarding'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.system_update_alt),
          title: const Text('Check for updates'),
          subtitle: const Text('Auto-checks daily; tap to check now (3/hr)'),
          onTap: () => manualCheckForUpdate(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Theme'),
          subtitle: Text(_themeLabel(ref.watch(themeModeProvider))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickTheme(context, ref),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Report a bug'),
          subtitle: const Text('Email (recommended) or in-app'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _reportBug(context),
        ),
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
          leading: const Icon(Icons.rule_folder_outlined),
          title: const Text('Smart Rules'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/rules'),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms & Conditions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/terms'),
        ),
        const SizedBox(height: 24),
        const SectionTitle('About'),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: const Text('Akash Priyadarshi'),
          subtitle: const Text('Developer · @AkashPriyadarshii'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _launch(context, 'https://github.com/AkashPriyadarshii'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.code),
          title: const Text('Kharcha on GitHub'),
          subtitle: const Text('Star the repo'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _launch(context, 'https://github.com/AkashPriyadarshii/kharcha'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.terminal),
          title: const Text('System Logs'),
          subtitle: const Text('View internal app events'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/logs'),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Account'),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout, color: expenseRed),
          title: const Text('Sign out', style: TextStyle(color: expenseRed)),
          subtitle: const Text('Your expenses remain safely on this device'),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your expenses stay on this device. Sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    authBypass.value = false; // also exit guest mode
    await Supabase.instance.client.auth.signOut();
  }

  /// Two ways to report a bug: Email (recommended — no account needed, lands
  /// straight in the inbox) or in-app (writes the `bug_reports` table).
  Future<void> _reportBug(BuildContext context) async {
    final env = await const BugReporter().describeEnvironment();
    if (!context.mounted) return;
    final choice = await showDialog<_ReportChannel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report a bug'),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.mail_outline),
            title: const Text('Email'),
            subtitle: const Text('Recommended — opens your mail app'),
            onTap: () => Navigator.pop(context, _ReportChannel.email),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.send_outlined),
            title: const Text('In-app'),
            subtitle: const Text('Sends via your signed-in Kharcha account'),
            onTap: () => Navigator.pop(context, _ReportChannel.app),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _ReportChannel.email:
        final uri = Uri(
          scheme: 'mailto',
          path: _supportEmail,
          queryParameters: {
            'subject': 'Kharcha bug report',
            'body': 'Describe the bug:\n\n\nDevice context:\n$env',
          },
        );
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) _fail(context, 'Could not open mail app.');
      case _ReportChannel.app:
        await _sendInAppReport(context, env);
    }
  }

  Future<void> _sendInAppReport(BuildContext context, String env) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Describe the bug'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(hintText: 'What went wrong?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (message == null || message.isEmpty || !context.mounted) return;
    try {
      await const BugReporter().report(message, environment: env);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. Thanks!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      _fail(context, 'Could not send: $e');
    }
  }

  void _fail(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// System/Light/Dark picker. System follows the OS; the other two force it.
  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(_themeLabel(mode)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(themeModeProvider.notifier).set(picked);
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follow system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool csv, bool anonymize = false}) async {
    try {
      // Always land in the user's Downloads folder (Android scoped storage
      // gives it without any permission on API 29+).
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File file;
      if (anonymize) {
        file = await Exporter(ref.read(transactionRepositoryProvider)).exportAnonymizedCsv(dir, 'kharcha_anonymized_$stamp.csv');
      } else {
        file = await (csv
            ? Exporter(ref.read(transactionRepositoryProvider)).exportCsv(dir, 'kharcha_$stamp.csv')
            : Exporter(ref.read(transactionRepositoryProvider)).exportJson(dir, 'kharcha_$stamp.json'));
      }
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

  Future<void> _launch(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
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
    final name = _userName(user);
    final initial = (name == null || name.isEmpty)
        ? null
        : name.substring(0, 1).toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: initial != null
                  ? Text(initial)
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
                          _userName(user) ?? 'Kharcha user',
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
      text: _userName(user) ?? '',
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
