import 'package:flutter/material.dart';

/// Terms & Conditions. In-app so users can consent without leaving — keeps
/// Play listing honest (no hidden ToS). Matches the public privacy-first layer.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Section(
            title: '1. What Kharcha does',
            body: 'Kharcha tracks your expenses. UPI payments can be '
                'auto-captured from notifications, on-device, with your '
                'explicit permission. Manual entry is always available.',
          ),
          const _Section(
            title: '2. Your data',
            body: 'Your expenses are stored on your device first. If you sign '
                'in with Google, they sync so they are backed up across your '
                'devices. We never sell your data, never share it with '
                'advertisers, and never use it for ad targeting.',
          ),
          const _Section(
            title: '3. Permissions',
            body: 'Notification access auto-captures UPI payments (opt-in, '
                'on-device, no SMS). Biometric/PIN powers the optional app '
                'lock. Notifications deliver daily and weekly summaries. You '
                'can revoke any permission anytime.',
          ),
          const _Section(
            title: '4. No financial advice',
            body: 'Kharcha is a tracking tool, not a bank or advisor. It does '
                'not handle money, store cards, or connect to your bank.',
          ),
          const _Section(
            title: '5. No warranty',
            body: 'Kharcha is provided "as is". We aim for correctness but '
                'you are responsible for verifying your own records.',
          ),
          const _Section(
            title: '6. Changes',
            body: 'These terms may be updated as Kharcha grows. Material '
                'changes will be communicated in-app.',
          ),
          const _Section(
            title: '7. Contact',
            body: 'Questions: owner via the GitHub repo '
                'AkashPriyadarshii/kharcha.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
