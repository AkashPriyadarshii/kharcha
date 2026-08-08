import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

/// Marks first-launch onboarding done. Persisted — shown once, after login.
class OnboardingStore {
  OnboardingStore(this.file);

  final File file;

  static Future<OnboardingStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return OnboardingStore(File('${dir.path}/onboarding.json'));
  }

  Future<bool> isDone() async {
    try {
      if (!await file.exists()) return false;
      return jsonDecode(await file.readAsString()) == true;
    } catch (_) {
      return false; // missing/corrupt → show onboarding.
    }
  }

  Future<void> markDone() => file.writeAsString(jsonEncode(true), flush: true);
}

/// One-time setup flow shown after first login:
///  1. Value prop
///  2. Enable UPI capture (notification access)
///  3. Allow summaries + ignore battery optimization
/// Every step is skippable — onboarding never traps the user.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _channel = MethodChannel('com.kharcha.app/capture');

  Future<void> _openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open settings: $e')));
    }
  }

  Future<void> _openCaptureSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationListenerSettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open settings: $e')));
    }
  }

  Future<void> _finish() async {
    await (await OnboardingStore.create()).markDone();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _finish(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Kharcha is set up.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Two quick steps and every UPI payment is tracked automatically.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _StepCard(
            step: '1',
            title: 'Auto-capture UPI payments',
            body: 'Allow notification access so GPay, PhonePe and Paytm payments save themselves. All on-device.',
            icon: Icons.notifications_active_outlined,
            actionLabel: 'Enable capture',
            onAction: () => _openCaptureSettings(),
          ),
          const SizedBox(height: 16),
          _StepCard(
            step: '2',
            title: 'Summaries + battery',
            body: 'Allow notifications for your 9PM daily recap, and let Kharcha ignore battery optimization so capture never sleeps.',
            icon: Icons.battery_charging_full,
            actionLabel: 'Open battery settings',
            onAction: () => _openBatterySettings(),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _finish(),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String step;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    step,
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
