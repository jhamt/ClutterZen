import 'package:firebase_auth/firebase_auth.dart'
    show
        FirebaseAuthException,
        PhoneAuthCredential,
        PhoneAuthProvider,
        UserCredential;
import 'package:flutter/material.dart';
import '../../app_firebase.dart';
import '../../services/user_service.dart';

import '../../services/i18n_service.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          I18nService.translate("Sign in with Phone"),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  hintText: I18nService.translate("+1 555 123 4567"),
                  labelText: I18nService.translate("Phone Number"),
                  filled: true,
                  fillColor: Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12))))),
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
                              ))
                          : Text(I18nService.translate("Send Code")))),
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
                    style: TextStyle(fontWeight: FontWeight.w600),
                  )),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  hintText: I18nService.translate("123456"),
                  labelText: I18nService.translate("Verification Code"),
                  filled: true,
                  fillColor: Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12))))),
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
                        ))
                    : Text(I18nService.translate("Verify & Sign In"))),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await AppFirebase.auth.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
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
        verificationFailed: (e) => setState(() => _msg = e.message),
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
    if (_verificationId == null) {
      setState(() => _msg = I18nService.translate("Request a code first."));
      return;
    }
    setState(() {
      _verifying = true;
      _msg = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: _code.text.trim());
      await _signInWithCredential(cred);
      if (mounted) {
        setState(() => _msg = I18nService.translate("Signed in successfully."));
      }
    } on FirebaseAuthException catch (e) {
      setState(() =>
          _msg = e.message ?? '${I18nService.translate("Failed")}: ${e.code}');
    } catch (e) {
      setState(() => _msg = '${I18nService.translate("Failed")}: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendToken == null) return;
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await AppFirebase.auth.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
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
        verificationFailed: (e) => setState(() => _msg = e.message),
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

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential =
          await AppFirebase.auth.signInWithCredential(credential);
      await UserService.ensureUserProfile(userCredential.user);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _msg = e.message ??
            '${I18nService.translate("Authentication failed")}: ${e.code}');
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _msg = '${I18nService.translate("Failed to sign in")}: $e');
      }
    }
  }
}
