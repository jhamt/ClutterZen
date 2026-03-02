import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../env.dart';

class AuthService {
  const AuthService(this._auth);

  final FirebaseAuth _auth;
  static Future<void>? _googleInitFuture;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      return _auth.signInWithPopup(provider);
    }

    await _ensureGoogleInitialized();
    try {
      return _authenticateGoogleUser();
    } on GoogleSignInException catch (e) {
      final code = e.code;
      final description = e.description?.trim();
      if ((code == GoogleSignInExceptionCode.canceled ||
              code == GoogleSignInExceptionCode.interrupted) &&
          _isGoogleAccountReauthFailure(description)) {
        try {
          // Clear any stale credential state and retry once.
          await GoogleSignIn.instance.signOut();
          return _authenticateGoogleUser();
        } on GoogleSignInException catch (_) {
          // Fall through to a clear actionable error.
        }
        throw FirebaseAuthException(
          code: 'clientConfigurationError',
          message:
              'Google sign-in failed due to account reauthentication. Add your release SHA-1/SHA-256 in Firebase, download a new google-services.json, then reinstall the app.',
        );
      }
      if (code == GoogleSignInExceptionCode.canceled ||
          code == GoogleSignInExceptionCode.interrupted) {
        final message = (description != null && description.isNotEmpty)
            ? 'Google sign-in was canceled or interrupted. $description'
            : 'Google sign-in was canceled or interrupted.';
        throw FirebaseAuthException(
          code: 'canceled',
          message: message,
        );
      }
      if (code == GoogleSignInExceptionCode.clientConfigurationError ||
          code == GoogleSignInExceptionCode.providerConfigurationError) {
        final message = (description != null && description.isNotEmpty)
            ? 'Google sign-in configuration issue. $description'
            : 'Google sign-in configuration issue. Verify Firebase project setup, package/bundle IDs, and SHA fingerprints.';
        throw FirebaseAuthException(
          code: code.name,
          message: message,
        );
      }
      throw FirebaseAuthException(
        code: code.name,
        message: (description != null && description.isNotEmpty)
            ? 'Google sign-in failed. $description'
            : 'Google sign-in failed: ${code.name}',
      );
    }
  }

  Future<UserCredential> _authenticateGoogleUser() async {
    final GoogleSignInAccount account =
        await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
    final GoogleSignInAuthentication tokens = account.authentication;
    final String? idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Missing ID token from Google sign-in.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  bool _isGoogleAccountReauthFailure(String? description) {
    if (description == null || description.isEmpty) return false;
    final normalized = description.toLowerCase();
    return normalized.contains('account reauth failed') ||
        normalized.contains('[16]');
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-web',
        message: 'Sign in with Apple is not supported on the web.',
      );
    }

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-unavailable',
        message: 'Sign in with Apple is not available on this device.',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    try {
      final credential = await _requestAppleCredential(nonce: nonce);

      if (credential.identityToken == null) {
        throw FirebaseAuthException(
          code: 'missing-identity-token',
          message: 'Apple did not return an identity token.',
        );
      }

      final oauth = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
      );
      return _auth.signInWithCredential(oauth);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Apple sign-in was canceled or interrupted.',
        );
      }
      throw FirebaseAuthException(
        code: 'apple-${e.code.name}',
        message: 'Apple sign-in failed. ${e.message}',
      );
    }
  }

  Future<AuthorizationCredentialAppleID> _requestAppleCredential({
    required String nonce,
  }) {
    const scopes = <AppleIDAuthorizationScopes>[
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ];

    if (defaultTargetPlatform != TargetPlatform.android) {
      return SignInWithApple.getAppleIDCredential(
        scopes: scopes,
        nonce: nonce,
      );
    }

    final clientId = Env.appleServiceId.trim();
    final redirectRaw = Env.appleRedirectUri.trim();
    if (clientId.isEmpty || redirectRaw.isEmpty) {
      throw FirebaseAuthException(
        code: 'apple-android-config-missing',
        message:
            'Apple sign-in on Android requires APPLE_SERVICE_ID and APPLE_REDIRECT_URI.',
      );
    }

    final redirectUri = Uri.tryParse(redirectRaw);
    if (redirectUri == null ||
        !redirectUri.isAbsolute ||
        !redirectUri.isScheme('https') ||
        redirectUri.host.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'apple-android-config-invalid',
        message:
            'APPLE_REDIRECT_URI must be a valid https URL for Apple sign-in on Android.',
      );
    }

    return SignInWithApple.getAppleIDCredential(
      scopes: scopes,
      nonce: nonce,
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: clientId,
        redirectUri: redirectUri,
      ),
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitFuture != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore Google sign-out errors; Firebase sign-out already completed.
      }
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static Future<void> _ensureGoogleInitialized() {
    final serverClientId = Env.googleServerClientId;
    return _googleInitFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }
}
