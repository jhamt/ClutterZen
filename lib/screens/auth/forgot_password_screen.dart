import 'package:flutter/material.dart';

import '../../app_firebase.dart';
import '../../services/i18n_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  String? _msg;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          I18nService.translate("Forgot Password"),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            I18nService.translate(
                "Enter your email and we'll send a reset link."),
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: I18nService.translate("Email"),
              hintText: I18nService.translate("Enter your email"),
              filled: true,
              fillColor: Color(0xFFF2F4F7),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _msg!.contains('Failed')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _msg!.contains('Failed')
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _msg!.contains('Failed')
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _msg!.contains('Failed')
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _msg!,
                      style: TextStyle(
                        color: _msg!.contains('Failed')
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              onPressed: _loading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
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
                  : Text(I18nService.translate("Send Reset Link")),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      await AppFirebase.auth.sendPasswordResetEmail(email: _email.text.trim());
      setState(() {
        _msg = I18nService.translate("Reset email sent.");
      });
    } catch (e) {
      setState(() {
        _msg = '${I18nService.translate("Failed")}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
