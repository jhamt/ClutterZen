import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../app_firebase.dart';
import '../env.dart';

/// Service for Stripe payment operations from the Flutter client.
///
/// Security model:
/// - Client uses Stripe publishable key only.
/// - Secret-key Stripe operations are proxied via Firebase Functions.
class StripeService {
  static bool _initialized = false;
  static String? _publishableKey;
  static String? _lastCreatedSubscriptionId;

  static String get _baseUrl {
    return Env.firebaseFunctionsUrl;
  }

  /// Initialize Stripe with publishable key from client-safe env.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _publishableKey = Env.stripePublishableKey.trim();

      if (_publishableKey == null || _publishableKey!.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'Warning: STRIPE_PUBLISHABLE_KEY not found. Stripe payments will not work.',
          );
        }
        _initialized = false;
        return;
      }

      Stripe.publishableKey = _publishableKey!;
      Stripe.merchantIdentifier = 'merchant.com.clutterzen';
      await Stripe.instance.applySettings();

      _initialized = true;
      if (kDebugMode) {
        debugPrint('Stripe initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing Stripe: $e');
      }
      _initialized = false;
    }
  }

  static bool get isInitialized => _initialized;
  static String? get publishableKey => _publishableKey;
  static String? get lastCreatedSubscriptionId => _lastCreatedSubscriptionId;

  static Future<Map<String, String>> _authHeaders() async {
    final user = AppFirebase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final idToken = await user.getIdToken();
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }

  /// Creates a subscription server-side and returns payment intent client secret.
  static Future<String> createSubscription({
    required String priceId,
    String? customerId,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/subscription/create'),
      headers: headers,
      body: jsonEncode({
        'priceId': priceId,
        if (customerId != null && customerId.isNotEmpty)
          'customerId': customerId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create subscription: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>?;
    final clientSecret = payload?['clientSecret'] as String?;
    final subscriptionId = payload?['subscriptionId'] as String?;

    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('No clientSecret returned from subscription create');
    }

    _lastCreatedSubscriptionId = subscriptionId;
    return clientSecret;
  }

  /// Presents Stripe PaymentSheet for subscription payment confirmation.
  static Future<void> presentSubscriptionSheet({
    required String priceId,
    String? customerId,
  }) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        throw Exception(
          'Stripe not initialized. Add STRIPE_PUBLISHABLE_KEY to .env.public or dart-define.',
        );
      }
    }

    try {
      final clientSecret = await createSubscription(
        priceId: priceId,
        customerId: customerId,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ClutterZen',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      throw Exception('Stripe error: ${e.error.message}');
    } catch (e) {
      throw Exception('Subscription failed: $e');
    }
  }

  /// Cancels a subscription at period end via Firebase Functions proxy.
  static Future<void> cancelSubscription(String subscriptionId) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/subscription/cancel'),
      headers: headers,
      body: jsonEncode({'subscriptionId': subscriptionId}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cancel subscription: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Gets subscription details via Firebase Functions proxy.
  static Future<Map<String, dynamic>> getSubscription(
      String subscriptionId) async {
    final headers = await _authHeaders();

    final response = await http.get(
      Uri.parse('$_baseUrl/stripe/subscription/$subscriptionId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get subscription: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
  }

  /// Activates Pro access after Stripe confirms subscription ownership/status.
  static Future<void> activateSubscription({
    required String subscriptionId,
    String planId = 'pro',
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/subscription/activate'),
      headers: headers,
      body: jsonEncode({
        'subscriptionId': subscriptionId,
        'planId': planId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to activate subscription: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Deprecated in favor of service-specific payment flow through Cloud Functions.
  static Future<String> createPaymentIntent({
    required double amount,
    String currency = 'usd',
    String? customerId,
  }) {
    throw UnsupportedError(
      'createPaymentIntent is deprecated in client. Use backend payment-intent endpoints instead.',
    );
  }

  /// Deprecated in favor of service-specific payment flow through Cloud Functions.
  static Future<void> presentPaymentSheet({
    required double amount,
    String currency = 'usd',
    String? customerId,
  }) {
    throw UnsupportedError(
      'presentPaymentSheet is deprecated in client. Use backend payment-intent endpoints instead.',
    );
  }
}
