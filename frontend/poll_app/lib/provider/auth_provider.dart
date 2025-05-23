import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import '../services/api.dart';

const String webClientId =
    '949437556974-thj3053bqt75eab906pq5a4nvfkosc59.apps.googleusercontent.com';
const String iosClientId =
    '949437556974-ftmsbp0aatoq0cfpus6ftjnp1d0givbq.apps.googleusercontent.com';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _init();
  }

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const ['email'],
    clientId: kIsWeb ? webClientId : (Platform.isIOS ? iosClientId : null),
  );

  GoogleSignInAccount? _user;
  bool _backendSessionValid = false;

  bool get isLoggedIn => _user != null && _backendSessionValid;

  bool _ready = false;
  bool get ready => _ready;

  bool _busy = false;
  bool get busy => _busy;

  Future<void> _init() async {
    final u = await fetchSessionUser();
    if (u != null) {
      _user = _PlaceholderGoogleUser(u['username']);
      _backendSessionValid = true;
    } else {
      final acct = await _gsi.signInSilently();
      if (acct != null) {
        final auth = await acct.authentication;
        final ok = await sendAuthToBackend(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
        if (ok) {
          _user = acct;
          _backendSessionValid = true;
        }
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> signIn() async {
    _busy = true;
    notifyListeners();
    try {
      final acct = await _gsi.signIn();
      if (acct == null) {
        _update(null, false);
        return;
      }

      final auth = await acct.authentication;
      final ok = await sendAuthToBackend(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      if (ok) {
        _update(acct, true);
      } else {
        await _gsi.signOut();
        _update(null, false);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _update(null, false);
  }

  void _update(GoogleSignInAccount? acct, bool sessionValid) {
    _user = acct;
    _backendSessionValid = sessionValid;
    _busy = false;
    notifyListeners();
  }
}

class _PlaceholderGoogleUser implements GoogleSignInAccount {
  _PlaceholderGoogleUser(this.email);
  @override final String email;
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
