import 'package:flutter/foundation.dart';

import '../env.dart';

/// Service for validating environment variables and configuration.
class EnvValidator {
  /// Validate all required/recommended environment variables.
  ///
  /// Returns a list of issues and warnings.
  static List<String> validateEnvironment() {
    final issues = <String>[];

    // Server proxy endpoint for Vision/Replicate/Stripe server actions.
    final functionsUrl = Env.firebaseFunctionsUrl.trim();
    if (functionsUrl.isEmpty) {
      issues.add(
        'FIREBASE_FUNCTIONS_URL is not set (required for server-side analysis and credit operations).',
      );
    } else {
      final functionsUri = Uri.tryParse(functionsUrl);
      final isValid = functionsUri != null &&
          (functionsUri.isScheme('https') || functionsUri.isScheme('http')) &&
          functionsUri.host.isNotEmpty;
      if (!isValid) {
        issues.add(
          'FIREBASE_FUNCTIONS_URL appears invalid (must be a full http/https URL).',
        );
      }
    }

    if (functionsUrl.contains('clutterzen-test.cloudfunctions.net')) {
      issues.add(
        'FIREBASE_FUNCTIONS_URL points to legacy test host (use your deployed project URL).',
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

    final visionKey = Env.dotEnvValue('VISION_API_KEY')?.trim() ?? '';
    if (visionKey.isNotEmpty) {
      issues.add(
        'VISION_API_KEY is present in client env (security risk; call Vision through Firebase Functions only).',
      );
    }

    final replicateToken = Env.dotEnvValue('REPLICATE_API_TOKEN')?.trim() ?? '';
    if (replicateToken.isNotEmpty) {
      issues.add(
        'REPLICATE_API_TOKEN is present in client env (security risk; call Replicate through Firebase Functions only).',
      );
    }

    // Gemini can run via Firebase Functions; client key is optional.
    final geminiKey = Env.dotEnvValue('GEMINI_API_KEY')?.trim() ?? '';
    if (geminiKey.isNotEmpty && !_isValidApiKey(geminiKey)) {
      issues.add('GEMINI_API_KEY appears to be invalid.');
    }
    if (geminiKey.isNotEmpty) {
      issues.add(
        'GEMINI_API_KEY is present in client env (recommended to proxy Gemini through Firebase Functions in production).',
      );
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
