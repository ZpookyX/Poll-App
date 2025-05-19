// main.dart ─ “same shape, up-to-date login”  (Flutter 3.22, google_sign_in 6.3.0)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

import 'screens/home_screen.dart';
import 'services/api.dart';          // unchanged helper that POSTs idToken

// ---------------------------------------------------------------------------
// OAuth client-IDs (only Web & iOS need an explicit string)
// ---------------------------------------------------------------------------
const String webClientId =
    '949437556974-thj3053bqt75eab906pq5a4nvfkosc59.apps.googleusercontent.com';
const String iosClientId =
    '949437556974-ftmsbp0aatoq0cfpus6ftjnp1d0givbq.apps.googleusercontent.com';

/// ---------------------------------------------------------------------------
/// AUTH PROVIDER (Google Sign-In)
/// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // kick off silent-login once at start-up
    _gsi.signInSilently().then(_update);
  }

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const ['email'],
    clientId: kIsWeb ? webClientId : (Platform.isIOS ? iosClientId : null),
  );

  GoogleSignInAccount? _user;
  bool get isLoggedIn => _user != null;

  bool _busy = false;
  bool get busy => _busy;

  void _update(GoogleSignInAccount? acct) {
    _user = acct;
    _busy = false;
    notifyListeners();
  }

  // --- public actions -------------------------------------------------------
  Future<void> signIn() async {
    _busy = true;
    notifyListeners();
    try {
      final acct = await _gsi.signIn();
      if (acct == null) return _update(null);

      final auth = await acct.authentication;

      if (await sendAuthToBackend(
          idToken: auth.idToken, accessToken: auth.accessToken)) {
        _update(acct);
      } else {
        await _gsi.signOut();
        _update(null);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _update(null);
  }

  // --- helpers --------------------------------------------------------------
  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }
}

/// ---------------------------------------------------------------------------
/// go_router (v15) redirect-logic – unchanged except for `matchedLocation`
/// ---------------------------------------------------------------------------
GoRouter createRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (_, state) {
    final loggedIn = auth.isLoggedIn;
    final onLogin = state.matchedLocation == '/login';
    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
  ],
);

void main() => runApp(
  ChangeNotifierProvider(create: (_) => AuthProvider(), child: const PollApp()),
);

class PollApp extends StatelessWidget {
  const PollApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp.router(
      title: 'Polls',
      theme: ThemeData(useMaterial3: true),
      routerConfig: createRouter(auth),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SIMPLE LOGIN SCREEN (style unchanged; now calls updated provider)
/// ---------------------------------------------------------------------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: auth.busy
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(240, 50)),
          onPressed: () => context.read<AuthProvider>().signIn(),
        ),
      ),
    );
  }
}
