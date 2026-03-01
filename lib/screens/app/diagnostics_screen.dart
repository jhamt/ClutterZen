import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../app_firebase.dart';
import '../../env.dart';

import '../../services/i18n_service.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fbInitialized = Firebase.apps.isNotEmpty;
    final user = AppFirebase.auth.currentUser;
    final functionsUrl = Env.firebaseFunctionsUrl.trim();
    final parsedFunctionsUri = Uri.tryParse(functionsUrl);
    final functionsUrlValid = functionsUrl.isNotEmpty &&
        parsedFunctionsUri != null &&
        (parsedFunctionsUri.isScheme('https') ||
            parsedFunctionsUri.isScheme('http')) &&
        parsedFunctionsUri.host.isNotEmpty;
    final usesLegacyTestHost =
        functionsUrl.contains('clutterzen-test.cloudfunctions.net');
    final geminiConfigured =
        functionsUrl.isNotEmpty || Env.geminiApiKey.isNotEmpty;
    final i18n = I18nService.getDiagnosticsSnapshot();

    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate("Diagnostics"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(I18nService.translate("Firebase initialized"), fbInitialized),
          _tile(I18nService.translate("Signed in"), user != null,
              trailing: user?.uid ?? '-'),
          _tile(I18nService.translate("FIREBASE_FUNCTIONS_URL configured"),
              functionsUrl.isNotEmpty),
          _tile(I18nService.translate("Functions URL format valid"),
              functionsUrlValid),
          _tile(
            I18nService.translate("Using legacy test functions host"),
            !usesLegacyTestHost,
            trailing: usesLegacyTestHost ? 'yes' : 'no',
          ),
          _tile(
            I18nService.translate("Resolved functions URL"),
            functionsUrlValid,
            subtitle: functionsUrl.isEmpty ? '(empty)' : functionsUrl,
          ),
          _tile(I18nService.translate("STRIPE_PUBLISHABLE_KEY set"),
              Env.stripePublishableKey.isNotEmpty),
          _tile(I18nService.translate("Gemini configured"), geminiConfigured),
          _tile(I18nService.translate("GOOGLE_SERVER_CLIENT_ID set"),
              Env.googleServerClientId.isNotEmpty),
          const SizedBox(height: 8),
          _tile(
            I18nService.translate("Current locale"),
            true,
            trailing: '${i18n['locale']}',
            subtitle:
                '${I18nService.translate("Loaded keys")}: ${i18n['loadedLocaleKeys']}/${i18n['totalKeys']}  |  ${I18nService.translate("Missing keys")}: ${i18n['missingKeys']}',
          ),
          const SizedBox(height: 12),
          Text(I18nService.translate("Tips:"),
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(I18nService.translate(
              "- Enable Developer Mode on Windows to allow plugin symlinks.")),
          Text(I18nService.translate(
              "- Run flutter clean && flutter pub get after moving directories.")),
        ],
      ),
    );
  }

  Widget _tile(
    String label,
    bool ok, {
    String? trailing,
    String? subtitle,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
