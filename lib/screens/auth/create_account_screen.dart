import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as siwa;

import '../../app_firebase.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

import '../../services/i18n_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const String _pendingVerificationPhoneKey =
      'pending_verification_phone';
  static const String _pendingVerificationEmailKey =
      'pending_verification_email';
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _appleAvailable = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  static final RegExp _emailRegex =
      RegExp(r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$', caseSensitive: false);
  static const Set<String> _allowedEmailDomains = <String>{
    'gmail.com',
    'googlemail.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'yahoo.com',
    'ymail.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'aol.com',
    'protonmail.com',
    'proton.me',
    'zoho.com',
    'gmx.com',
  };

  @override
  void initState() {
    super.initState();
    _password.addListener(_checkPasswordStrength);
    siwa.SignInWithApple.isAvailable().then((value) {
      if (mounted) setState(() => _appleAvailable = value);
    });
  }

  @override
  void dispose() {
    _password.removeListener(_checkPasswordStrength);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    String strengthText;
    Color strengthColor;
    if (strength <= 2) {
      strengthText = I18nService.translate("Weak");
      strengthColor = Colors.red;
    } else if (strength <= 3) {
      strengthText = I18nService.translate("Fair");
      strengthColor = Colors.orange;
    } else if (strength <= 4) {
      strengthText = I18nService.translate("Good");
      strengthColor = Colors.blue;
    } else {
      strengthText = I18nService.translate("Strong");
      strengthColor = Colors.green;
    }

    setState(() {
      _passwordStrength = strengthText;
      _passwordStrengthColor = strengthColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          I18nService.translate("Sign up Account"),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              const SizedBox(height: 16),
              Text(
                I18nService.translate("Sign up Account"),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                I18nService.translate(
                    "Join now for a faster, smarter shopping experience."),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
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
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: I18nService.translate("Full Name"),
                  hintText: I18nService.translate("Enter your name"),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return I18nService.translate("Please enter your full name");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: I18nService.translate("Email"),
                  hintText: I18nService.translate("Enter your email"),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return I18nService.translate("Please enter your email");
                  }
                  if (!_isValidEmail(value.trim())) {
                    return I18nService.translate(
                        "Please enter a valid email address");
                  }
                  if (!_isSupportedEmailProvider(value.trim())) {
                    return I18nService.translate(
                        "Use a supported provider (Gmail, Outlook, Yahoo, iCloud, etc.).");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: I18nService.translate("Password"),
                  hintText: I18nService.translate("Enter your password"),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return I18nService.translate("Please enter a password");
                  }
                  if (value.length < 8) {
                    return I18nService.translate(
                        "Password must be at least 8 characters");
                  }
                  return null;
                },
              ),
              if (_passwordStrength.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      I18nService.translate("Password strength: "),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      _passwordStrength,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _passwordStrengthColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: I18nService.translate("Confirm Password"),
                  hintText: I18nService.translate("Re-enter your password"),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return I18nService.translate(
                        "Please confirm your password");
                  }
                  if (value != _password.text) {
                    return I18nService.translate("Passwords do not match");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: I18nService.translate("Phone Number"),
                  hintText: I18nService.translate("Enter your phone number"),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  final normalized = _normalizePhone(value ?? '');
                  if (normalized.isEmpty) {
                    return I18nService.translate("Phone number is required");
                  }
                  if (!_isValidPhoneE164(normalized)) {
                    return I18nService.translate(
                        "Use international format, e.g. +923001234567");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
                  onPressed: _loading ? null : _create,
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
                      : Text(I18nService.translate("Sign up")),
                ),
              ),
              const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _google,
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
                    onPressed: _loading ? null : _apple,
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(I18nService.translate("Already have an account? ")),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      I18nService.translate("Sign in"),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _error = I18nService.translate("Please enter a valid email address");
      });
      return;
    }
    if (!_isSupportedEmailProvider(email)) {
      setState(() {
        _error = I18nService.translate(
            "Use a supported provider (Gmail, Outlook, Yahoo, iCloud, etc.).");
      });
      return;
    }

    final normalizedPhone = _normalizePhone(_phone.text);
    if (!_isValidPhoneE164(normalizedPhone)) {
      setState(() {
        _error = I18nService.translate(
            "Use international phone format, e.g. +923001234567");
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AppFirebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: _password.text,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: I18nService.translate("Failed to create account"),
        );
      }

      await user.updateDisplayName(_name.text.trim());

      // Create profile only after auth is established.
      await UserService.ensureUserProfile(user);

      // Save unverified phone intent and continue to OTP verification flow.
      await AppFirebase.firestore.collection('users').doc(user.uid).set(
        {
          'pendingPhoneNumber': normalizedPhone,
          'phoneVerified': false,
        },
        SetOptions(merge: true),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingVerificationPhoneKey, normalizedPhone);
      await prefs.setString(_pendingVerificationEmailKey, email);

      if (!mounted) return;
      Navigator.of(context).pushNamed(
        '/phone',
        arguments: <String, dynamic>{
          'initialPhone': normalizedPhone,
          'initialEmail': email,
          'lockPhone': true,
          'autoSendCode': true,
          'verificationMode': 'signup',
        },
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = I18nService.translate("Failed to create account");
      if (e.code == 'email-already-in-use') {
        errorMessage = I18nService.translate(
            "This email is already registered. Please sign in instead.");
      } else if (e.code == 'weak-password') {
        errorMessage = I18nService.translate(
            "Password is too weak. Please choose a stronger password.");
      } else if (e.code == 'invalid-email') {
        errorMessage = I18nService.translate(
            "Invalid email address. Please check and try again.");
      } else {
        errorMessage =
            '${I18nService.translate("Failed")}: ${e.message ?? e.code}';
      }
      setState(() => _error = errorMessage);
    } catch (e) {
      final raw = e.toString().toLowerCase();
      if (raw.contains('permission-denied')) {
        setState(() {
          _error = I18nService.translate(
              "Profile creation is blocked by Firestore rules. Please deploy latest rules and try again.");
        });
      } else {
        setState(() => _error = '${I18nService.translate("Failed")}: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? error;
    try {
      final cred = await AuthService(AppFirebase.auth).signInWithGoogle();
      await UserService.ensureUserProfile(cred.user);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      error = _socialAuthErrorMessage(e);
    } catch (e) {
      error = 'Failed: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _apple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? error;
    try {
      if (!_appleAvailable) {
        throw FirebaseAuthException(
          code: 'apple-sign-in-unavailable',
          message: I18nService.translate(
              "Sign in with Apple is not supported on this device."),
        );
      }
      final cred = await AuthService(AppFirebase.auth).signInWithApple();
      await UserService.ensureUserProfile(cred.user);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      error = _socialAuthErrorMessage(e);
    } catch (e) {
      error = '${I18nService.translate("Failed")}: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  String _socialAuthErrorMessage(FirebaseAuthException e) {
    if (e.code == 'canceled') {
      return e.message ??
          I18nService.translate("Sign-in was canceled or interrupted.");
    }
    return '${I18nService.translate("Failed")}: ${e.message ?? e.code}';
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

  bool _isSupportedEmailProvider(String email) {
    final atIndex = email.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == email.length - 1) return false;
    final domain = email.substring(atIndex + 1).toLowerCase().trim();
    return _allowedEmailDomains.contains(domain);
  }

  String _normalizePhone(String input) {
    final compact = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (compact.startsWith('00')) {
      return '+${compact.substring(2)}';
    }
    return compact;
  }

  bool _isValidPhoneE164(String input) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(input);
  }
}
