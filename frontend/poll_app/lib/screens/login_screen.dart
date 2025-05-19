import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show Auth;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<Auth>();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: auth.busy
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          onPressed: () => context.read<Auth>().signIn(),
        ),
      ),
    );
  }
}
