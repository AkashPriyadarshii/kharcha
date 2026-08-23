import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config.dart' show onboardingDone;

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

/// One-time setup flow after login. 4 steps, one at a time:
///  0. Value prop — why Kharcha (no permissions asked yet)
///  1. Enable UPI capture (notification access) — live status
///  2. Allow daily summaries (notification permission) — live status
///  3. Keep capture awake (battery exemption) — live status, then finish
/// Every step skippable — onboarding never traps. Live status from
/// `getCaptureStatus` so granted/denied is visible and auto-advances.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _channel = MethodChannel('com.kharcha.app/capture');

  static const _titles = [
    'Track every UPI payment. Automatically.',
    'Auto-capture UPI & Bank SMS',
    'Daily summaries',
    'Keep capture awake',
  ];
  static const _bodies = [
    'Kharcha reads your UPI payment notifications (GPay, PhonePe, Paytm) and bank SMS, saving each expense itself. No manual entry. 100% on-device.',
    'Allow notification access so payments save themselves. SMS access is optional for bank alerts.',
    'Allow notifications for your 9PM recap and budget alerts.',
    'Let Kharcha ignore battery optimization so auto-capture never sleeps.',
  ];
  static const _icons = [
    Icons.auto_awesome,
    Icons.notifications_active_outlined,
    Icons.notifications_outlined,
    Icons.battery_charging_full,
  ];
  static const _actions = [
    null, // intro step has no permission action
    'Enable notification capture',
    'Allow notifications',
    'Allow battery exemption',
  ];

  int _step = 0;
  bool _capture = false;
  bool _sms = false;
  bool _notifications = false;
  bool _battery = false;
  Timer? _statusTimer;

  /// Best-effort platform call; failures show a snackbar, never block setup.
  Future<void> _invoke(String method, {String fallback = 'Could not complete that step.'}) async {
    try {
      await _channel.invokeMethod<void>(method);
      await _refreshStatus(); // reflect the result of the permission prompt
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$fallback $e')));
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await _channel.invokeMethod<Map>('getCaptureStatus');
      if (!mounted || status == null) return;
      setState(() {
        _capture = status['capture'] == true;
        _sms = status['sms'] == true;
        _notifications = status['notifications'] == true;
        _battery = status['battery'] == true;
      });
    } catch (_) {
      // Non-Android / unsupported — no status; keep current values.
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    // Realtime: poll permission state so a grant/deny made in system settings
    // reflects immediately — the channel has no event stream to listen on.
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  bool get _stepDone {
    switch (_step) {
      case 1:
        return _capture || _sms;
      case 2:
        return _notifications;
      case 3:
        return _battery;
      default:
        return false;
    }
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      _refreshStatus();
    } else {
      _finish();
    }
  }

  void _skip() {
    if (_step < 3) {
      setState(() => _step++);
      _refreshStatus();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await (await OnboardingStore.create()).markDone();
    onboardingDone.value = true; // flip the router gate — markDone alone didn't
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIntro = _step == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: isIntro ? _skip : _finish,
            child: Text(isIntro ? 'Skip' : 'Skip all'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isIntro) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_step) / 3,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Step $_step of 3',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
              ],
              Expanded(
                child: isIntro
                    ? _IntroStep(
                        icon: _icons[0],
                        title: _titles[0],
                        body: _bodies[0],
                      )
                    : _PermissionStep(
                        step: _step,
                        title: _titles[_step],
                        body: _bodies[_step],
                        icon: _icons[_step],
                        actionLabel: _actions[_step]!,
                        isDone: _stepDone,
                        secondaryActionLabel: _step == 1 ? 'Enable SMS capture (Optional)' : null,
                        secondaryDone: _step == 1 ? _sms : null,
                        onSecondaryAction: _step == 1 ? () => _invoke('requestSmsPermission') : null,
                        onAction: () => _invoke(
                          switch (_step) {
                            1 => 'openNotificationListenerSettings',
                            2 => 'requestNotificationPermission',
                            _ => 'requestBatteryOptimizationExemption',
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              if (isIntro)
                FilledButton.icon(
                  onPressed: () => _next(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Let\'s set up'),
                )
              else
                FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(_stepDone ? Icons.check : Icons.arrow_forward),
                  label: Text(_stepDone ? 'Continue' : 'I\'ll do this later'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.step,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.isDone,
    required this.onAction,
    this.secondaryActionLabel,
    this.secondaryDone,
    this.onSecondaryAction,
  });

  final int step;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final bool isDone;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final bool? secondaryDone;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              isDone ? 'Notification Listener: Active' : 'Notification Listener: Not active',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                secondaryDone == true ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: secondaryDone == true
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                secondaryDone == true ? 'Bank SMS: Active' : 'Bank SMS: Not enabled (optional)',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
