import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app_firebase.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
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

  @override
  void initState() {
    super.initState();
    _password.addListener(_checkPasswordStrength);
    SignInWithApple.isAvailable().then((value) {
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
      strengthText = 'Weak';
      strengthColor = Colors.red;
    } else if (strength <= 3) {
      strengthText = 'Fair';
      strengthColor = Colors.orange;
    } else if (strength <= 4) {
      strengthText = 'Good';
      strengthColor = Colors.blue;
    } else {
      strengthText = 'Strong';
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
        title: const Text(
          'Sign up Account',
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
            child: const Text(
              'Skip',
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
                'Sign up Account',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join now for a faster, smarter shopping experience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
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
                  labelText: 'Full Name',
                  hintText: 'Enter your name',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
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
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
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
                      'Password strength: ',
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
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
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
                    return 'Please confirm your password';
                  }
                  if (value != _password.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'Enter your phone number',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                      : const Text('Sign up'),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('OR'),
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
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _google,
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _apple,
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Sign in',
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check if display name already exists (optional check)
      final nameQuery = await AppFirebase.firestore
          .collection('users')
          .where('displayName', isEqualTo: _name.text.trim())
          .limit(1)
          .get();

      if (nameQuery.docs.isNotEmpty) {
        setState(() {
          _error =
              'This name is already taken. Please choose a different name.';
          _loading = false;
        });
        return;
      }

      final cred = await AppFirebase.auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      await cred.user?.updateDisplayName(_name.text.trim());

      // Create user profile doc
      final userData = {
        'displayName': _name.text.trim(),
        'email': _email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'scanCredits': 3,
      };

      // Add phone number if provided
      if (_phone.text.trim().isNotEmpty) {
        userData['phoneNumber'] = _phone.text.trim();
        // Phone number will need to be verified separately through phone auth flow
      }

      await AppFirebase.firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(userData);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to create account';
      if (e.code == 'email-already-in-use') {
        errorMessage =
            'This email is already registered. Please sign in instead.';
      } else if (e.code == 'weak-password') {
        errorMessage =
            'Password is too weak. Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address. Please check and try again.';
      } else {
        errorMessage = 'Failed: ${e.message ?? e.code}';
      }
      setState(() => _error = errorMessage);
    } catch (e) {
      setState(() => _error = 'Failed: $e');
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
      error = 'Failed: ${e.message ?? e.code}';
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
          message: 'Sign in with Apple is not supported on this device.',
        );
      }
      final cred = await AuthService(AppFirebase.auth).signInWithApple();
      await UserService.ensureUserProfile(cred.user);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      error = 'Failed: ${e.message ?? e.code}';
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
}
