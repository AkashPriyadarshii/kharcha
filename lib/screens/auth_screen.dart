import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null,
        // Web only; harmless on Android. Keeps sign-in in-app where possible.
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Kharcha', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Every UPI payment, auto-tracked.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _signIn(context),
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/terms'),
                child: const Text('Terms & Conditions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
