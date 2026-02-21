import 'package:flutter/foundation.dart';

import '../env.dart';

/// Service for validating environment variables and configuration.
class EnvValidator {
  static const String _defaultFunctionsUrl =
      'https://us-central1-clutterzen-test.cloudfunctions.net/api';

  /// Validate all required/recommended environment variables.
  ///
  /// Returns a list of issues and warnings.
  static List<String> validateEnvironment() {
    final issues = <String>[];

    // Server proxy endpoint for Vision/Replicate/Stripe server actions.
    final functionsUrl = Env.firebaseFunctionsUrl.trim();
    if (functionsUrl.isEmpty) {
      issues.add(
        'FIREBASE_FUNCTIONS_URL is not set (recommended; app falls back to default endpoint).',
      );
    } else if (functionsUrl == _defaultFunctionsUrl) {
      issues.add(
        'FIREBASE_FUNCTIONS_URL is using default test endpoint (set your own project URL for production).',
      );
    }

    // Stripe publishable key is the only Stripe key allowed on client.
    final stripePublishableKey = Env.stripePublishableKey.trim();
    if (stripePublishableKey.isEmpty) {
      issues.add(
        'STRIPE_PUBLISHABLE_KEY is not set (payment features will not work).',
      );
    } else if (!stripePublishableKey.startsWith('pk_')) {
      issues.add(
        'STRIPE_PUBLISHABLE_KEY appears invalid (should start with pk_).',
      );
    }

    // Client apps should not ship secret keys.
    final stripeSecretKey = Env.dotEnvValue('STRIPE_SECRET_KEY')?.trim() ?? '';
    if (stripeSecretKey.isNotEmpty) {
      issues.add(
        'STRIPE_SECRET_KEY is present in client env (security risk; move to Firebase Functions only).',
      );
    }

    // Gemini powers recommendation tabs.
    final geminiKey = Env.geminiApiKey.trim();
    if (geminiKey.isEmpty) {
      issues.add(
        'GEMINI_API_KEY is not set (AI recommendation tabs will be limited).',
      );
    } else if (!_isValidApiKey(geminiKey)) {
      issues.add('GEMINI_API_KEY appears to be invalid.');
    }

    // Recommended for robust Google Sign-In on Android/iOS.
    final googleServerClientId = Env.googleServerClientId.trim();
    if (googleServerClientId.isEmpty) {
      issues.add(
        'GOOGLE_SERVER_CLIENT_ID is not set (recommended for Google Sign-In token exchange).',
      );
    }

    return issues;
  }

  /// Check if API key format is valid.
  static bool _isValidApiKey(String key) {
    if (key.isEmpty) return false;
    if (key.length < 20) return false;
    if (key.toLowerCase().contains('your_') ||
        key.toLowerCase().contains('placeholder') ||
        key.toLowerCase().contains('example')) {
      return false;
    }
    return true;
  }

  /// Validate publishable Stripe key format.
  static bool validateStripeKeys({
    String? publishableKey,
  }) {
    if (publishableKey == null || publishableKey.isEmpty) {
      return false;
    }
    return publishableKey.startsWith('pk_');
  }

  /// Runtime environment check.
  static void performRuntimeCheck() {
    if (!kDebugMode) return;

    final issues = validateEnvironment();
    if (issues.isNotEmpty) {
      debugPrint('[WARNING] Environment Configuration Issues:');
      for (final issue in issues) {
        debugPrint('  - $issue');
      }
      debugPrint(
        '\n[TIP] Use .env.public for client-safe values and keep secrets in backend/Firebase Functions env.\n'
        'See .env.public.example and .env.example for templates.\n',
      );
    } else {
      debugPrint('[OK] Environment configuration validated successfully');
    }
  }

  /// Check if app is properly configured for production.
  static bool isProductionReady() {
    final issues = validateEnvironment();

    // Treat recommendations as non-blocking. Security and hard failures block.
    final blocking = issues.where((issue) {
      return issue.contains('security risk') ||
          issue.contains('will not work') ||
          issue.contains('appears invalid');
    }).toList();

    return blocking.isEmpty;
  }
}
