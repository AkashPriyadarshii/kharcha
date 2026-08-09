import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_inbox.dart';
import '../data/transaction_repository.dart';

/// First-launch disclosure: explain notification access + link to Settings.
/// Once enabled, drains the inbox (adds any captured expenses).
class EnableCaptureScreen extends ConsumerStatefulWidget {
  const EnableCaptureScreen({super.key});

  @override
  ConsumerState<EnableCaptureScreen> createState() => _EnableCaptureScreenState();
}

class _EnableCaptureScreenState extends ConsumerState<EnableCaptureScreen> {
  @override
  void initState() {
    super.initState();
    _drain();
  }

  Future<void> _drain() async {
    final repo = ref.read(transactionRepositoryProvider);
    await drainCaptureInbox(inbox: await captureInboxFile(), repo: repo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable capture')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kharcha can auto-add your UPI payments.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('We read your payment notifications (GPay, PhonePe, Paytm) and save them as expenses — automatically. All on your device, nothing sent anywhere.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    // Launches Android's notification-listener Settings toggle (MainActivity
    // exposes the channel). Errors are surfaced, not swallowed.
    const channel = MethodChannel('com.kharcha.app/capture');
    channel.invokeMethod<void>('openNotificationListenerSettings').catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open settings: $e')));
    });
  }
}
