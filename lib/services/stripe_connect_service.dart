import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_firebase.dart';
import '../env.dart';

/// Service for managing Stripe Connect accounts via Firebase Functions proxy.
///
/// Security model:
/// - Client uses only public values (Stripe Connect client ID).
/// - Secret-key Stripe operations run server-side in Firebase Functions.
class StripeConnectService {
  static String get _baseUrl {
    return Env.firebaseFunctionsUrl;
  }

  static bool get isConfigured => _baseUrl.isNotEmpty;

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

  /// Create a connected account (server-side Stripe call).
  static Future<String> createConnectedAccount({
    required String email,
    String type = 'standard',
    String? country,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Stripe Connect not configured. Add STRIPE_CONNECT_CLIENT_ID to client env.',
      );
    }

    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/connect/create-account'),
      headers: headers,
      body: jsonEncode({
        'email': email,
        'type': type,
        if (country != null && country.isNotEmpty) 'country': country,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Failed to create connected account: '
        '${error['error'] ?? response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accountId = data['data']?['accountId'] as String?;
    if (accountId == null || accountId.isEmpty) {
      throw Exception('No accountId in response');
    }
    return accountId;
  }

  /// Get connected account details (server-side Stripe call).
  static Future<Map<String, dynamic>> getConnectedAccount(
      String accountId) async {
    final headers = await _authHeaders();

    final response = await http.get(
      Uri.parse('$_baseUrl/stripe/connect/account/$accountId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Failed to get connected account: '
        '${error['error'] ?? response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
  }

  /// Create onboarding account link (server-side Stripe call).
  static Future<String> createAccountLink({
    required String accountId,
    String? returnUrl,
    String? refreshUrl,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/connect/create-account-link'),
      headers: headers,
      body: jsonEncode({
        'accountId': accountId,
        if (returnUrl != null && returnUrl.isNotEmpty) 'returnUrl': returnUrl,
        if (refreshUrl != null && refreshUrl.isNotEmpty)
          'refreshUrl': refreshUrl,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Failed to create account link: '
        '${error['error'] ?? response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['data']?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No URL in response');
    }
    return url;
  }

  /// Requests a secure Stripe OAuth URL from Firebase Functions.
  static Future<String> createOAuthAuthorizationUrl() async {
    if (!isConfigured) {
      throw Exception(
        'Stripe Connect OAuth not configured. Set FIREBASE_FUNCTIONS_URL.',
      );
    }
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/connect/oauth/start'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Failed to create OAuth URL: ${error['error'] ?? response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['data']?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No OAuth URL in response');
    }
    return url;
  }

  /// OAuth code exchange is handled by backend callback endpoint.
  static Future<String> exchangeOAuthCode(String code) {
    throw UnsupportedError(
      'exchangeOAuthCode is handled server-side via /stripe/oauth/return callback.',
    );
  }

  /// Create payment intent for connected account via Firebase Functions.
  static Future<String> createPaymentIntentForAccount({
    required String accountId,
    required double amount,
    String currency = 'usd',
    double? applicationFeeAmount,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$_baseUrl/stripe/connect/create-payment-intent'),
      headers: headers,
      body: jsonEncode({
        'accountId': accountId,
        'amount': amount,
        'currency': currency,
        if (applicationFeeAmount != null)
          'applicationFeeAmount': applicationFeeAmount,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Failed to create payment intent: ${error['error'] ?? response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = data['data']?['clientSecret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('No clientSecret in response');
    }
    return clientSecret;
  }

  /// Launch OAuth flow in external browser.
  static Future<void> launchOAuthFlow() async {
    final oauthUrl = await createOAuthAuthorizationUrl();

    final uri = Uri.parse(oauthUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch OAuth URL');
    }
  }

  /// Check if account can accept payouts/charges.
  static Future<bool> isAccountReady(String accountId) async {
    try {
      final account = await getConnectedAccount(accountId);
      final chargesEnabled = account['charges_enabled'] as bool? ?? false;
      final payoutsEnabled = account['payouts_enabled'] as bool? ?? false;
      final detailsSubmitted = account['details_submitted'] as bool? ?? false;

      return chargesEnabled && payoutsEnabled && detailsSubmitted;
    } catch (_) {
      return false;
    }
  }
}
