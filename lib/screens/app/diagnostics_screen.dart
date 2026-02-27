import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../app_firebase.dart';
import '../../env.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fbInitialized = Firebase.apps.isNotEmpty;
    final user = AppFirebase.auth.currentUser;
    final geminiConfigured =
        Env.firebaseFunctionsUrl.isNotEmpty || Env.geminiApiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile('Firebase initialized', fbInitialized),
          _tile('Signed in', user != null, trailing: user?.uid ?? '-'),
          _tile('FIREBASE_FUNCTIONS_URL set',
              Env.firebaseFunctionsUrl.isNotEmpty),
          _tile('STRIPE_PUBLISHABLE_KEY set',
              Env.stripePublishableKey.isNotEmpty),
          _tile('Gemini configured', geminiConfigured),
          _tile('GOOGLE_SERVER_CLIENT_ID set',
              Env.googleServerClientId.isNotEmpty),
          const SizedBox(height: 12),
          const Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              '- Enable Developer Mode on Windows to allow plugin symlinks.'),
          const Text(
              '- Run flutter clean && flutter pub get after moving directories.'),
        ],
      ),
    );
  }

  Widget _tile(String label, bool ok, {String? trailing}) {
    return ListTile(
      title: Text(label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child:
                  Text(trailing, style: const TextStyle(color: Colors.grey))),
        Icon(ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? Colors.green : Colors.red),
      ]),
    );
  }
}
