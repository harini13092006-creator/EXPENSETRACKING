import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provider adapters that exchange native credentials with Firebase Auth.
/// On web, Firebase owns the OAuth popup and redirect handling.
class SocialAuthService {
  SocialAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static bool _googleInitialized = false;

  Future<UserCredential> signIn(String provider) => _run(provider, link: false);

  Future<UserCredential> link(String provider) => _run(provider, link: true);

  Future<UserCredential> _run(String provider, {required bool link}) async {
    final user = _auth.currentUser;
    if (link && user == null)
      throw FirebaseAuthException(code: 'no-current-user');

    switch (provider) {
      case 'google':
        if (kIsWeb) {
          final p = GoogleAuthProvider();
          return _web(p, user, link);
        }
        if (!_googleInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleInitialized = true;
        }
        late final GoogleSignInAccount account;
        try {
          account = await GoogleSignIn.instance.authenticate();
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) {
            throw FirebaseAuthException(code: 'social-login-cancelled');
          }
          rethrow;
        }
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(code: 'missing-google-id-token');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        return link
            ? user!.linkWithCredential(credential)
            : _auth.signInWithCredential(credential);

      case 'facebook':
        if (kIsWeb) {
          final p = FacebookAuthProvider()..addScope('email');
          return _web(p, user, link);
        }
        final result = await FacebookAuth.instance.login();
        if (result.status == LoginStatus.cancelled) {
          throw FirebaseAuthException(code: 'social-login-cancelled');
        }
        final accessToken = result.accessToken;
        if (result.status != LoginStatus.success || accessToken == null) {
          throw FirebaseAuthException(code: 'facebook-login-failed');
        }
        final credential = FacebookAuthProvider.credential(
          accessToken.tokenString,
        );
        return link
            ? user!.linkWithCredential(credential)
            : _auth.signInWithCredential(credential);

      case 'apple':
        final p = AppleAuthProvider();
        return _provider(p, user, link);

      case 'microsoft':
        final p = MicrosoftAuthProvider();
        return _provider(p, user, link);

      default:
        throw ArgumentError.value(provider, 'provider', 'Unsupported provider');
    }
  }

  Future<UserCredential> _web(AuthProvider provider, User? user, bool link) {
    if (link) return user!.linkWithPopup(provider);
    return _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _provider(
    AuthProvider provider,
    User? user,
    bool link,
  ) async {
    if (kIsWeb) {
      return link
          ? user!.linkWithPopup(provider)
          : _auth.signInWithPopup(provider);
    }
    return link
        ? user!.linkWithProvider(provider)
        : _auth.signInWithProvider(provider);
  }
}

String socialAuthErrorMessage(
  FirebaseAuthException error,
) => switch (error.code) {
  'social-login-cancelled' ||
  'web-context-canceled' ||
  'popup-closed-by-user' => 'Sign-in was cancelled.',
  'account-exists-with-different-credential' || 'credential-already-in-use' => 'An account already uses this email or provider. Sign in with that method first, then link it from Settings.',
  'provider-already-linked' =>
    'This provider is already linked to your account.',
  'no-current-user' => 'Sign in before linking another provider.',
  'network-request-failed' =>
    'Could not connect. Check your internet connection and try again.',
  'operation-not-allowed' =>
    'This sign-in method is not enabled in Firebase Authentication.',
  'unauthorized-domain' =>
    'This domain is not authorized in Firebase Authentication settings.',
  'invalid-credential' || 'invalid-oauth-client-id' => 'The provider rejected this sign-in. Check its Firebase and provider console configuration.',
  'missing-google-id-token' => 'Google did not return an ID token. Check the Android/iOS OAuth client setup.',
  _ =>
    'Could not sign in with this provider (${error.code}). Check the provider configuration and try again.',
};
