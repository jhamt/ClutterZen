import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, PhoneAuthCredential, PhoneAuthProvider, User;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_firebase.dart';
import '../../services/i18n_service.dart';
import '../../services/user_service.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({
    super.key,
    this.initialPhone,
    this.initialEmail,
    this.lockPhone = false,
    this.autoSendCode = false,
    this.verificationMode,
  });

  final String? initialPhone;
  final String? initialEmail;
  final bool lockPhone;
  final bool autoSendCode;
  final String? verificationMode;

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  static const String _pendingVerificationPhoneKey =
      'pending_verification_phone';
  static const String _pendingVerificationEmailKey =
      'pending_verification_email';
  static const Duration _resendCooldown = Duration(minutes: 1);
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  String? _msg;
  bool _contextReady = false;
  String _verificationEmail = '';
  int _resendSecondsRemaining = 0;
  Timer? _resendCooldownTimer;
  bool _hasSentVerificationEmail = false;

  bool get _hasValidVerificationEmail => _isValidEmail(_verificationEmail);

  bool get _isVerificationFlow {
    if ((widget.verificationMode ?? '').trim().isNotEmpty) {
      return widget.verificationMode == 'signup' ||
          widget.verificationMode == 'signin';
    }
    final currentUser = AppFirebase.auth.currentUser;
    return _requiresEmailVerification(currentUser);
  }

  @override
  void initState() {
    super.initState();
    _bootstrapContext();
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isVerificationFlow
        ? I18nService.translate("Verify Email")
        : I18nService.translate("Sign in with Phone");
    final verifyButtonLabel = _isVerificationFlow
        ? I18nService.translate("Verify & Continue")
        : I18nService.translate("Verify & Sign In");

    if (!_contextReady) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          if (_msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
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
                      _msg!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          if (!_isVerificationFlow) ...[
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              enabled: !(widget.lockPhone || _sending || _verifying),
              decoration: InputDecoration(
                hintText: I18nService.translate("+1 555 123 4567"),
                labelText: I18nService.translate("Phone Number"),
                filled: true,
                fillColor: const Color(0xFFF2F4F7),
                border: const OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            if (widget.lockPhone) ...[
              const SizedBox(height: 8),
              Text(
                I18nService.translate(
                  "Phone number is locked for this signup verification.",
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Container(
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
                    onPressed: _sending ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(I18nService.translate("Send Code")),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  onPressed:
                      (_resendToken == null || _sending) ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 48),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    I18nService.translate("Resend"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]),
          ] else ...[
            if (_verificationEmail.trim().isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: Text(
                  _hasSentVerificationEmail
                      ? '${I18nService.translate("Code sent to")} ${_maskEmail(_verificationEmail.trim())}'
                      : '${I18nService.translate("Verification target")}: ${_maskEmail(_verificationEmail.trim())}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: I18nService.translate("123456"),
              labelText: I18nService.translate("Verification Code"),
              filled: true,
              fillColor: const Color(0xFFF2F4F7),
              border: const OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(verifyButtonLabel),
            ),
          ),
          if (_isVerificationFlow) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_sending ||
                      !_hasValidVerificationEmail ||
                      _resendSecondsRemaining > 0)
                  ? null
                  : _resend,
              child: Text(
                _resendSecondsRemaining > 0
                    ? I18nService.translate(
                        "Resend Code (${_resendSecondsRemaining}s)")
                    : I18nService.translate("Resend Code"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_isVerificationFlow) {
      await _clearPendingVerificationEmail();
      await _clearPendingVerificationPhone();
      await AppFirebase.auth.signOut();
    }
    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
  }

  Future<void> _bootstrapContext() async {
    var initialPhone = _normalizePhone(widget.initialPhone ?? '');
    var initialEmail = (widget.initialEmail ?? '').trim();

    if (_isVerificationFlow) {
      final currentUser = AppFirebase.auth.currentUser;
      if (initialEmail.isEmpty && currentUser != null) {
        initialEmail = (currentUser.email ?? '').trim();
      }
      if (initialEmail.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          initialEmail =
              (prefs.getString(_pendingVerificationEmailKey) ?? '').trim();
        } catch (_) {
          // Ignore local storage read errors.
        }
      }
      if (initialPhone.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          initialPhone = _normalizePhone(
              prefs.getString(_pendingVerificationPhoneKey) ?? '');
        } catch (_) {
          // Ignore local storage read errors.
        }
      }
    } else if (initialPhone.isEmpty) {
      initialPhone = _normalizePhone(widget.initialPhone ?? '');
    }

    if (!mounted) return;
    if (initialPhone.isNotEmpty) {
      _phone.text = initialPhone;
    }
    setState(() {
      _verificationEmail = initialEmail;
      _contextReady = true;
    });

    final shouldAutoSend = widget.autoSendCode;
    if (shouldAutoSend && _isVerificationFlow && _hasValidVerificationEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sending) return;
        _sendCode();
      });
      return;
    }

    if (shouldAutoSend && !_isVerificationFlow && initialPhone.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _verificationId != null || _sending) return;
        _sendCode();
      });
      return;
    }

    if (_isVerificationFlow && !_hasValidVerificationEmail && mounted) {
      setState(() {
        _msg = I18nService.translate(
          "Verification email is missing. Go back and sign in again with a valid email address.",
        );
      });
    }
  }

  Future<void> _sendCode() async {
    if (_isVerificationFlow) {
      await _sendEmailVerification(isResend: false);
      return;
    }

    final normalizedPhone = _normalizePhone(_phone.text);
    if (!_isValidPhoneE164(normalizedPhone)) {
      setState(() {
        _msg = _isVerificationFlow
            ? I18nService.translate(
                "Verification phone is missing. Go back and sign up again with a valid +countrycode phone number.")
            : I18nService.translate(
                "Enter a valid phone in international format, e.g. +923001234567");
      });
      return;
    }
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await AppFirebase.auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (cred) async {
          try {
            await _signInWithCredential(cred);
            if (mounted) {
              setState(() =>
                  _msg = I18nService.translate("Signed in automatically."));
            }
          } catch (e) {
            if (mounted) {
              setState(() => _msg = '${I18nService.translate("Failed")}: $e');
            }
          }
        },
        verificationFailed: (e) =>
            setState(() => _msg = _phoneAuthErrorMessage(e)),
        codeSent: (verificationId, resendToken) => setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _msg = I18nService.translate("Code sent.");
        }),
        codeAutoRetrievalTimeout: (verificationId) =>
            setState(() => _verificationId = verificationId),
      );
    } catch (e) {
      setState(() => _msg = '${I18nService.translate("Failed")}: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_isVerificationFlow) {
      await _verifyEmailAndContinue();
      return;
    }

    if (_verificationId == null) {
      setState(() => _msg = I18nService.translate("Request a code first."));
      return;
    }
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _msg = I18nService.translate("Enter the 6-digit verification code.");
      });
      return;
    }
    setState(() {
      _verifying = true;
      _msg = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: code);
      await _signInWithCredential(cred);
      if (mounted) {
        setState(() => _msg = I18nService.translate("Signed in successfully."));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = _phoneAuthErrorMessage(e));
    } catch (e) {
      setState(() => _msg = '${I18nService.translate("Failed")}: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_isVerificationFlow) {
      await _sendEmailVerification(isResend: true);
      return;
    }

    if (_resendToken == null) return;
    final normalizedPhone = _normalizePhone(_phone.text);
    if (!_isValidPhoneE164(normalizedPhone)) {
      setState(() {
        _msg = I18nService.translate(
            "Enter a valid phone in international format, e.g. +923001234567");
      });
      return;
    }
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await AppFirebase.auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        forceResendingToken: _resendToken,
        verificationCompleted: (cred) async {
          try {
            await _signInWithCredential(cred);
            if (mounted) {
              setState(() =>
                  _msg = I18nService.translate("Signed in automatically."));
            }
          } catch (e) {
            if (mounted) {
              setState(() => _msg = '${I18nService.translate("Failed")}: $e');
            }
          }
        },
        verificationFailed: (e) =>
            setState(() => _msg = _phoneAuthErrorMessage(e)),
        codeSent: (verificationId, resendToken) => setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _msg = I18nService.translate("Code re-sent.");
        }),
        codeAutoRetrievalTimeout: (verificationId) =>
            setState(() => _verificationId = verificationId),
      );
    } catch (e) {
      setState(() => _msg = '${I18nService.translate("Failed")}: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendEmailVerification({required bool isResend}) async {
    if (_resendSecondsRemaining > 0 && isResend) {
      setState(() {
        _msg = I18nService.translate(
          "Please wait ${_resendSecondsRemaining}s before requesting a new code.",
        );
      });
      return;
    }

    final currentUser = AppFirebase.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _msg = I18nService.translate(
          "Session expired. Please sign in again to continue verification.",
        );
      });
      return;
    }

    final email = (currentUser.email ?? _verificationEmail).trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _msg = I18nService.translate(
          "Verification email is missing. Go back and sign in again with a valid email address.",
        );
      });
      return;
    }

    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await currentUser.sendEmailVerification();
      await _rememberPendingVerificationEmail(email);
      if (!mounted) return;
      setState(() {
        _verificationEmail = email;
        _hasSentVerificationEmail = true;
        _msg = isResend
            ? I18nService.translate("Code re-sent to your email.")
            : I18nService.translate("Code sent to your email.");
      });
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'too-many-requests') {
          _msg = I18nService.translate(
              "Too many attempts. Please wait before trying again.");
        } else {
          _msg = '${I18nService.translate("Failed")}: ${e.message ?? e.code}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = '${I18nService.translate("Failed")}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _verifyEmailAndContinue() async {
    setState(() {
      _verifying = true;
      _msg = null;
    });
    try {
      final currentUser = AppFirebase.auth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: I18nService.translate(
            "Session expired. Please sign in again to continue verification.",
          ),
        );
      }

      await currentUser.reload();
      final refreshedUser = AppFirebase.auth.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        if (mounted) {
          setState(() {
            _msg = I18nService.translate(
              "Email is not verified yet. Open your email, tap the verification link, then return and try again.",
            );
          });
        }
        return;
      }

      await UserService.ensureUserProfile(refreshedUser);
      await AppFirebase.firestore
          .collection('users')
          .doc(refreshedUser.uid)
          .set(
        {
          'emailVerified': true,
        },
        SetOptions(merge: true),
      );
      await _clearPendingVerificationEmail();

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _msg = e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _msg = '${I18nService.translate("Failed to verify email")}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final currentUser = AppFirebase.auth.currentUser;
      User? resolvedUser;

      if (_shouldLinkPhoneToCurrentUser(currentUser)) {
        try {
          final linked = await currentUser!.linkWithCredential(credential);
          resolvedUser = linked.user ?? currentUser;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            resolvedUser = currentUser;
          } else if (e.code == 'credential-already-in-use' ||
              e.code == 'account-exists-with-different-credential') {
            final signedIn = await AppFirebase.auth.signInWithCredential(
              credential,
            );
            resolvedUser = signedIn.user;
          } else {
            rethrow;
          }
        }
      } else {
        final signedIn =
            await AppFirebase.auth.signInWithCredential(credential);
        resolvedUser = signedIn.user;
      }

      if (resolvedUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: I18nService.translate("Could not resolve account user."),
        );
      }

      await UserService.ensureUserProfile(resolvedUser);
      final verifiedPhone = (resolvedUser.phoneNumber ?? _phone.text).trim();
      if (verifiedPhone.isNotEmpty) {
        await AppFirebase.firestore
            .collection('users')
            .doc(resolvedUser.uid)
            .set(
          {
            'phoneNumber': verifiedPhone,
            'pendingPhoneNumber': FieldValue.delete(),
            'phoneVerified': true,
          },
          SetOptions(merge: true),
        );
      }
      await _clearPendingVerificationPhone();
      await _clearPendingVerificationEmail();

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _msg = _phoneAuthErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _msg = '${I18nService.translate("Failed to sign in")}: $e');
      }
    }
  }

  bool _requiresEmailVerification(User? user) {
    if (user == null) return false;
    final hasPasswordProvider =
        user.providerData.any((provider) => provider.providerId == 'password');
    return hasPasswordProvider && !user.emailVerified;
  }

  bool _shouldLinkPhoneToCurrentUser(User? user) {
    if (user == null) return false;
    final hasPasswordProvider =
        user.providerData.any((provider) => provider.providerId == 'password');
    final hasPhone = (user.phoneNumber ?? '').trim().isNotEmpty;
    return hasPasswordProvider && !hasPhone;
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final localPart = parts.first;
    final domainPart = parts.last;
    if (localPart.length <= 2) {
      return '${localPart[0]}*@$domainPart';
    }
    final visibleStart = localPart.substring(0, 1);
    final visibleEnd = localPart.substring(localPart.length - 1);
    final masked = '*' * (localPart.length - 2);
    return '$visibleStart$masked$visibleEnd@$domainPart';
  }

  Future<void> _clearPendingVerificationPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingVerificationPhoneKey);
    } catch (_) {
      // Ignore local storage cleanup failures.
    }
  }

  Future<void> _rememberPendingVerificationEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingVerificationEmailKey, email.trim());
    } catch (_) {
      // Ignore local storage write failures.
    }
  }

  Future<void> _clearPendingVerificationEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingVerificationEmailKey);
    } catch (_) {
      // Ignore local storage cleanup failures.
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _resendSecondsRemaining = _resendCooldown.inSeconds;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _resendSecondsRemaining -= 1;
      });
    });
  }

  String _phoneAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return I18nService.translate(
            "Phone number format is invalid. Use international format like +923001234567.");
      case 'invalid-verification-code':
        return I18nService.translate(
            "Verification code is incorrect. Please try again.");
      case 'session-expired':
        return I18nService.translate(
            "Code expired. Request a new verification code.");
      case 'too-many-requests':
        return I18nService.translate(
            "Too many attempts. Please wait and try again.");
      case 'quota-exceeded':
        return I18nService.translate("SMS quota exceeded. Try again later.");
      case 'network-request-failed':
        return I18nService.translate(
            "Network error. Check connection and retry.");
      case 'app-not-authorized':
        return I18nService.translate(
            "Phone sign-in is not authorized for this app build. Check Firebase SHA/app configuration.");
      case 'provider-already-linked':
        return I18nService.translate(
            "This phone is already linked. You can continue.");
      default:
        return e.message ??
            '${I18nService.translate("Authentication failed")}: ${e.code}';
    }
  }
}
