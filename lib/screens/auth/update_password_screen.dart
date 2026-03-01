import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart' show EmailAuthProvider;

import '../../app_firebase.dart';

import '../../services/i18n_service.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  bool _loading = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate("Update Password"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(
                  hintText: I18nService.translate("Current Password"),
                  filled: true,
                  fillColor: Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12))))),
          const SizedBox(height: 12),
          TextField(
              controller: _new,
              obscureText: true,
              decoration: InputDecoration(
                  hintText: I18nService.translate("New Password"),
                  filled: true,
                  fillColor: Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12))))),
          const SizedBox(height: 16),
          if (_msg != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8), child: Text(_msg!)),
          ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(I18nService.translate("Save"))),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final user = AppFirebase.auth.currentUser;
      if (user == null || user.email == null) {
        throw I18nService.translate("Not signed in");
      }
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _current.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_new.text);
      setState(() {
        _msg = I18nService.translate("Password updated.");
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
