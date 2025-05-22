import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import '../services/api.dart';

/// ---------------------------------------------------------------------------
/// OAuth client-IDs (only Web & iOS need an explicit string)
/// ---------------------------------------------------------------------------
const String webClientId =
    '949437556974-thj3053bqt75eab906pq5a4nvfkosc59.apps.googleusercontent.com';
const String iosClientId =
    '949437556974-ftmsbp0aatoq0cfpus6ftjnp1d0givbq.apps.googleusercontent.com';

/// ---------------------------------------------------------------------------
/// AUTH PROVIDER (Google Sign-In)
/// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  AuthProvider() { _init(); }                         // start-up logic

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const ['email'],
    clientId: kIsWeb ? webClientId : (Platform.isIOS ? iosClientId : null),
  );

  GoogleSignInAccount? _user;
  bool get isLoggedIn => _user != null;

  bool _ready = false;
  bool get ready => _ready;

  bool _busy = false;
  bool get busy => _busy;

  Future<void> _init() async {
    final u = await fetchSessionUser();
    if (u != null) {
      _user = _PlaceholderGoogleUser(u['username']);
    } else {
      await _gsi.signInSilently().then(_update);
    }
    _ready = true;
    notifyListeners();
  }

  // ---------- public actions ------------------------------------------------
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

  // ---------- helpers -------------------------------------------------------
  void _update(GoogleSignInAccount? acct) {
    _user = acct;
    _busy = false;
    notifyListeners();
  }
}

/// stand-in account when session-cookie is used (e-mail only)
class _PlaceholderGoogleUser implements GoogleSignInAccount {
  _PlaceholderGoogleUser(this.email);
  @override final String email;
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
