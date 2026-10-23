import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Inicio de sesión con Google que termina autenticando en Firebase.
/// Firebase Auth persiste la sesión, por lo que el usuario queda recordado.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  Future<void>? _googleInit;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() =>
      _googleInit ??= GoogleSignIn.instance.initialize();

  /// Devuelve `null` si el usuario cancela el selector de cuentas.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    }

    await _ensureGoogleInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google no entregó un idToken. Revisa la configuración OAuth '
        '(SHA-1 en Android / GIDClientID en iOS).',
      );
    }
    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }
}
