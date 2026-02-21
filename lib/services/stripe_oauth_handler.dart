import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_firebase.dart';
import '../env.dart';

/// Service for handling Stripe OAuth callbacks and state management
///
/// This service manages:
/// - OAuth state generation and validation
/// - Handling OAuth callbacks
/// - Deep linking for mobile apps
class StripeOAuthHandler {
  /// Generate OAuth state token for security
  ///
  /// Uses user ID and timestamp to create a unique state
  static String generateOAuthState(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final state = '$userId:$timestamp';
    return base64Encode(utf8.encode(state));
  }

  /// Validate OAuth state token
  ///
  /// Extracts user ID from state and validates it matches current user
  static String? validateOAuthState(String state) {
    try {
      final decoded = utf8.decode(base64Decode(state));
      final parts = decoded.split(':');
      if (parts.length != 2) return null;

      final userId = parts[0];
      final timestamp = int.tryParse(parts[1]);

      if (timestamp == null) return null;

      // Check if state is not too old (5 minutes max)
      final stateAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (stateAge > 5 * 60 * 1000) {
        return null; // State expired
      }

      return userId;
    } catch (e) {
      debugPrint('Error validating OAuth state: $e');
      return null;
    }
  }

  /// Handle OAuth callback from Stripe
  ///
  /// This is called when Stripe redirects back after OAuth authorization
  ///
  /// [code] - Authorization code from Stripe
  /// [state] - State parameter for validation
  ///
  /// Returns the connected account ID
  static Future<String> handleOAuthCallback({
    required String code,
    required String state,
  }) async {
    final userId = validateOAuthState(state);
    if (userId == null) {
      throw Exception('Invalid or expired OAuth state');
    }

    // Verify current user matches state
    final currentUser = AppFirebase.auth.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      throw Exception('OAuth state does not match current user');
    }

    // Exchange code for account ID via Firebase Function
    // This keeps the secret key server-side
    final functionsUrl = _getFunctionsUrl();
    final idToken = await currentUser.getIdToken();

    final response = await http.get(
      Uri.parse('$functionsUrl/stripe/oauth/return').replace(queryParameters: {
        'code': code,
        'state': state,
      }),
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 302) {
      // 302 is redirect, which is expected
      if (response.statusCode == 302) {
        // Extract account ID from Firestore (will be saved by function)
        // For now, we'll need to poll or use a webhook
        throw Exception(
          'OAuth completed. Please refresh to see your connected account.',
        );
      }

      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to complete OAuth');
    }

    // The function redirects, so we need to get account ID from Firestore
    // Wait a moment for Firestore write to complete
    await Future.delayed(const Duration(seconds: 1));

    // Get account ID from Firestore
    final accountDoc = await AppFirebase.firestore
        .collection('stripe_connected_accounts')
        .doc(userId)
        .get();

    if (!accountDoc.exists) {
      throw Exception('Account not found after OAuth completion');
    }

    final accountId = accountDoc.data()?['accountId'] as String?;
    if (accountId == null) {
      throw Exception('Account ID not found');
    }

    return accountId;
  }

  /// Get Firebase Functions URL
  static String _getFunctionsUrl() {
    return Env.firebaseFunctionsUrl;
  }

  /// Create account link via Firebase Function
  ///
  /// This keeps the secret key server-side
  static Future<String> createAccountLinkViaFunction({
    required String accountId,
    String? returnUrl,
    String? refreshUrl,
  }) async {
    final functionsUrl = _getFunctionsUrl();
    final user = AppFirebase.auth.currentUser;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$functionsUrl/stripe/connect/create-account-link'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'accountId': accountId,
        if (returnUrl != null && returnUrl.isNotEmpty) 'returnUrl': returnUrl,
        if (refreshUrl != null && refreshUrl.isNotEmpty)
          'refreshUrl': refreshUrl,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create account link');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['data']?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No URL in response');
    }
    return url;
  }
}
