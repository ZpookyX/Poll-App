import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: auth.busy
          // Loading spinner while signing in
            ? const CircularProgressIndicator()
          // ---------- Login button ----------
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(240, 50)),
          // Trigger Google Sign-In through AuthProvider
          onPressed: () => context.read<AuthProvider>().signIn(),
        ),
      ),
    );
  }
}