import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      // Native Google sign-in (Android). Avoids the PKCE redirect-to-localhost
      // trap that the in-app-webview OAuth flow hits on devices.
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _fail('Google returned no ID token. Try again.');
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      // Root cause of the name bug: signInWithIdToken does NOT reliably copy
      // Google's profile claims into user_metadata (no full_name/name key), so
      // the name UI falls back to "Kharcha user". We already hold the account
      // from Google itself — write it once so every screen just reads `name`.
      final meta = Supabase.instance.client.auth.currentUser!.userMetadata ?? const {};
      if (meta['name'] == null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {...meta, 'name': account.displayName}),
        );
      }
      if (!mounted) return;
      context.go('/');
    } on GoogleSignInException catch (e) {
      _fail('Google sign-in failed: ${e.description}');
    } catch (e) {
      _fail('Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: Text(_busy ? 'Signing in…' : 'Sign in with Google'),
              ),
              const SizedBox(height: 8),
              // ponytail: guest mode — pre-release, no publishing yet. Grants
              // no Supabase session, so sync no-ops and RLS-protected
              // endpoints stay unreachable. Local-only use.
              TextButton.icon(
                onPressed: () => authBypass.value = true,
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as guest'),
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
