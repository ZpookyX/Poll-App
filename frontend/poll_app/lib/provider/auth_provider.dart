import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import '../services/api.dart';

// Specific client id's for web and IOS. Android relies on SHA-1 fingerprint in Google Cloud Console
// but we still have Android client-id in backend for token verification
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
  bool _backendSessionValid = false;  // Tracks whether the backend accepted the Google token

  // Checks if the user is logged in both with Google and the backend.
  bool get isLoggedIn => _user != null && _backendSessionValid;

  bool _ready = false;  // This variable is to signal when init() is done
  bool get ready => _ready;

  bool _busy = false; // Make sure we can't have concurrent login attempts
  bool get busy => _busy;

  // Initializes login state: checks backend session first,
  // then attempts silent Google Sign-In if needed.
  Future<void> _init() async {
    final u = await fetchSessionUser();

    if (u != null) {
      // A dummy google user has to be created since a backend-session is
      // already valid. We don't have to login again but google needs a
      // google user
      _user = _PlaceholderGoogleUser(u['username']);
      _backendSessionValid = true;

    } else {
      // If no session was found try to silently login
      final acct = await _gsi.signInSilently();
      if (acct != null) {
        final auth = await acct.authentication;
        final ok = await sendAuthToBackend(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
        // Treat it as logged-in if backend accepts tokens
        if (ok) {
          _user = acct;
          _backendSessionValid = true;
        }
      }
    }

    _ready = true;
    notifyListeners();
  }

  // This function triggers when we click on the login button in the login_screen
  Future<void> signIn() async {
    _busy = true;
    notifyListeners();
    try {
      final acct = await _gsi.signIn(); // This opens google UI
      if (acct == null) {
        // User cancelled sign-in
        _update(null, false);
        return;
      }

      final auth = await acct.authentication; // Retrieves the tokens
      final ok = await sendAuthToBackend( // Makes sure backend accepts
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      if (ok) {
        // Everything went well
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
  // To be able to log out in profile, marks backend session as false
  Future<void> signOut() async {
    await _gsi.signOut();
    _update(null, false);
  }

  // A function used in this file to update values easier
  void _update(GoogleSignInAccount? acct, bool sessionValid) {
    _user = acct;
    _backendSessionValid = sessionValid;
    _busy = false;
    notifyListeners();
  }
}

// A way you can get past Google login when logged in with session cookie
class _PlaceholderGoogleUser implements GoogleSignInAccount {
  _PlaceholderGoogleUser(this.email);
  @override final String email;
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
