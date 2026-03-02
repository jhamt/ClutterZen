import 'package:firebase_auth/firebase_auth.dart';
import '../../app_firebase.dart';
import '../../services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as siwa;

import '../../services/auth_service.dart';

import '../../services/i18n_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _appleAvailable = false;
  static final RegExp _emailRegex =
      RegExp(r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    siwa.SignInWithApple.isAvailable().then((v) {
      if (mounted) setState(() => _appleAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false),
            child: Text(
              I18nService.translate("Skip"),
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            const SizedBox(height: 16),
            Image.asset('assets/clutterzen-logo-color.png', height: 72),
            const SizedBox(height: 16),
            Text(I18nService.translate("Welcome back"),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              I18nService.translate(
                  "Access your orders, wishlist, and exclusive offers by logging in."),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: I18nService.translate("Email"),
                filled: true,
                fillColor: const Color(0xFFF2F4F7),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            _PasswordField(controller: _password),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _signInEmail,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(I18nService.translate("Sign in")),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/forgot-password'),
                child: Text(
                  I18nService.translate("Forgot password?"),
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(I18nService.translate("OR")),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: _loading ? null : _signInGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brands/google_g_logo.png',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      I18nService.translate("Continue with Google"),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_appleAvailable)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton(
                  onPressed: _loading ? null : _signInApple,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apple, size: 30),
                      SizedBox(width: 12),
                      Text(
                        I18nService.translate("Continue with Apple"),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            if (_appleAvailable) const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).pushNamed('/phone'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smartphone_rounded, size: 25),
                    SizedBox(width: 12),
                    Text(
                      I18nService.translate("Continue with Phone"),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(I18nService.translate("Don't have an account? ")),
              GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed('/create-account'),
                  child: Text(I18nService.translate("Sign Up here"),
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _signInEmail() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _error = I18nService.translate("Please enter a valid email address");
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    String? errorMessage;
    try {
      final cred = await AppFirebase.auth.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      errorMessage = await _handleSignedIn(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        errorMessage = I18nService.translate(
            "No account found with this email. Please sign up first.");
      } else if (e.code == 'wrong-password') {
        errorMessage =
            I18nService.translate("Incorrect password. Please try again.");
      } else if (e.code == 'invalid-email') {
        errorMessage = I18nService.translate(
            "Invalid email address. Please check and try again.");
      } else if (e.code == 'user-disabled') {
        errorMessage = I18nService.translate(
            "This account has been disabled. Please contact support.");
      } else {
        errorMessage =
            '${I18nService.translate("Failed to sign in")}: ${e.message ?? e.code}';
      }
    } catch (e) {
      errorMessage = '${I18nService.translate("Failed to sign in")}: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorMessage;
        });
      }
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? errorMessage;
    try {
      final cred = await AuthService(AppFirebase.auth).signInWithGoogle();
      errorMessage = await _handleSignedIn(cred);
    } on FirebaseAuthException catch (e) {
      errorMessage = _socialAuthErrorMessage(e);
    } catch (e) {
      errorMessage = 'Failed: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorMessage;
        });
      }
    }
  }

  Future<void> _signInApple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? errorMessage;
    try {
      if (!_appleAvailable) {
        throw FirebaseAuthException(
          code: 'apple-sign-in-unavailable',
          message: I18nService.translate(
              "Sign in with Apple is not supported on this device."),
        );
      }
      final cred = await AuthService(AppFirebase.auth).signInWithApple();
      errorMessage = await _handleSignedIn(cred);
    } on FirebaseAuthException catch (e) {
      errorMessage = _socialAuthErrorMessage(e);
    } catch (e) {
      errorMessage = '${I18nService.translate("Failed")}: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorMessage;
        });
      }
    }
  }

  Future<String?> _handleSignedIn(UserCredential cred) async {
    final user = cred.user;
    if (user == null) {
      return I18nService.translate("Authentication failed.");
    }

    await user.reload();
    final refreshedUser = AppFirebase.auth.currentUser ?? user;

    await UserService.ensureUserProfile(refreshedUser);
    if (_requiresEmailVerification(refreshedUser)) {
      if (mounted) {
        Navigator.of(context).pushNamed(
          '/phone',
          arguments: <String, dynamic>{
            'initialPhone': '',
            'initialEmail': refreshedUser.email ?? '',
            'lockPhone': false,
            'autoSendCode': true,
            'verificationMode': 'signin',
          },
        );
      }
      return null;
    }

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
    return null;
  }

  String _socialAuthErrorMessage(FirebaseAuthException e) {
    if (e.code == 'canceled') {
      return e.message ??
          I18nService.translate("Sign-in was canceled or interrupted.");
    }
    return '${I18nService.translate("Failed")}: ${e.message ?? e.code}';
  }

  bool _requiresEmailVerification(User user) {
    final hasPasswordProvider =
        user.providerData.any((provider) => provider.providerId == 'password');
    return hasPasswordProvider && !user.emailVerified;
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (!_emailRegex.hasMatch(email)) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final local = parts.first;
    final domain = parts.last;
    if (local.startsWith('.') || local.endsWith('.')) return false;
    if (local.contains('..') || domain.contains('..')) return false;
    if (domain.startsWith('-') || domain.endsWith('-')) return false;
    if (!domain.contains('.')) return false;
    return true;
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller});
  final TextEditingController controller;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        hintText: I18nService.translate("Password"),
        filled: true,
        fillColor: const Color(0xFFF2F4F7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure)),
      ),
    );
  }
}
