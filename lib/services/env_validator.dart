import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../env.dart';

/// Service for validating environment variables and configuration
class EnvValidator {
  /// Validate all required environment variables
  ///
  /// Returns a list of missing or invalid variables
  static List<String> validateEnvironment() {
    final issues = <String>[];

    // Check Vision API Key
    final visionKey = dotenv.env['VISION_API_KEY']?.trim() ?? Env.visionApiKey;
    if (visionKey.isEmpty) {
      issues.add('VISION_API_KEY is not set');
    } else if (!_isValidApiKey(visionKey)) {
      issues.add('VISION_API_KEY appears to be invalid');
    }

    // Check Replicate Token
    final replicateToken =
        dotenv.env['REPLICATE_API_TOKEN']?.trim() ?? Env.replicateToken;
    if (replicateToken.isEmpty) {
      issues.add('REPLICATE_API_TOKEN is not set');
    } else if (!_isValidApiKey(replicateToken)) {
      issues.add('REPLICATE_API_TOKEN appears to be invalid');
    }

    // Check Stripe keys (optional but recommended)
    final stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim();
    final stripeSecretKey = dotenv.env['STRIPE_SECRET_KEY']?.trim();
    if (stripePublishableKey == null || stripePublishableKey.isEmpty) {
      issues.add(
          'STRIPE_PUBLISHABLE_KEY is not set (payment features will not work)');
    } else if (!stripePublishableKey.startsWith('pk_')) {
      issues.add(
          'STRIPE_PUBLISHABLE_KEY appears to be invalid (should start with pk_)');
    }

    if (stripeSecretKey == null || stripeSecretKey.isEmpty) {
      issues
          .add('STRIPE_SECRET_KEY is not set (payment features will not work)');
    } else if (!stripeSecretKey.startsWith('sk_')) {
      issues.add(
          'STRIPE_SECRET_KEY appears to be invalid (should start with sk_)');
    }

    return issues;
  }

  /// Check if API key format is valid
  static bool _isValidApiKey(String key) {
    if (key.isEmpty) return false;
    // Basic validation: should be at least 20 characters and not be placeholder
    if (key.length < 20) return false;
    if (key.toLowerCase().contains('your_') ||
        key.toLowerCase().contains('placeholder') ||
        key.toLowerCase().contains('example')) {
      return false;
    }
    return true;
  }

  /// Validate Stripe keys format
  static bool validateStripeKeys({
    String? publishableKey,
    String? secretKey,
  }) {
    if (publishableKey == null || secretKey == null) {
      return false;
    }

    // Publishable keys start with pk_ (test or live)
    if (!publishableKey.startsWith('pk_')) {
      return false;
    }

    // Secret keys start with sk_ (test or live)
    if (!secretKey.startsWith('sk_')) {
      return false;
    }

    // Ensure they're from the same environment (both test or both live)
    final publishableIsTest = publishableKey.startsWith('pk_test_');
    final secretIsTest = secretKey.startsWith('sk_test_');

    if (publishableIsTest != secretIsTest) {
      if (kDebugMode) {
        debugPrint(
          'Warning: Stripe keys appear to be from different environments (test vs live)',
        );
      }
      return false;
    }

    return true;
  }

  /// Runtime environment check
  ///
  /// Logs warnings for missing configuration in debug mode
  static void performRuntimeCheck() {
    if (!kDebugMode) return;

    final issues = validateEnvironment();
    if (issues.isNotEmpty) {
      debugPrint('[WARNING] Environment Configuration Issues:');
      for (final issue in issues) {
        debugPrint('  - $issue');
      }
      debugPrint(
        '\n[TIP] Create a .env file in the project root with your API keys.\n'
        'See .env.example for a template.\n',
      );
    } else {
      debugPrint('[OK] Environment configuration validated successfully');
    }
  }

  /// Check if app is properly configured for production
  static bool isProductionReady() {
    final issues = validateEnvironment();
    // Filter out warnings (Stripe keys are optional for basic functionality)
    final criticalIssues = issues
        .where((issue) =>
            !issue.contains('STRIPE') || issue.contains('will not work'))
        .toList();
    return criticalIssues.isEmpty;
  }
}
