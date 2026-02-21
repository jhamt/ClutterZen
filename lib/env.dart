import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Safe access to dotenv values; returns null when dotenv was not loaded.
  static String? dotEnvValue(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  // --- AI Services ---
  // Prioritize build-time value (dart-define), fallback to .env file
  static String get visionApiKey =>
      _get('VISION_API_KEY', const String.fromEnvironment('VISION_API_KEY'));
  static String get replicateToken => _get('REPLICATE_API_TOKEN',
      const String.fromEnvironment('REPLICATE_API_TOKEN'));

  // --- Google Gemini AI ---
  static String get geminiApiKey =>
      _get('GEMINI_API_KEY', const String.fromEnvironment('GEMINI_API_KEY'));

  // --- Firebase Functions ---
  static String get firebaseFunctionsUrl => _get(
      'FIREBASE_FUNCTIONS_URL',
      const String.fromEnvironment(
        'FIREBASE_FUNCTIONS_URL',
        defaultValue:
            'https://us-central1-clutterzen-test.cloudfunctions.net/api',
      ));

  // --- Firebase Web Config (Optional - use google-services.json instead for Android/iOS) ---
  static String get firebaseApiKey => _get(
      'FIREBASE_API_KEY', const String.fromEnvironment('FIREBASE_API_KEY'));
  static String get firebaseAuthDomain => _get('FIREBASE_AUTH_DOMAIN',
      const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'));
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID',
      const String.fromEnvironment('FIREBASE_PROJECT_ID'));
  static String get firebaseStorageBucket => _get('FIREBASE_STORAGE_BUCKET',
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'));
  static String get firebaseMessagingSenderId => _get(
      'FIREBASE_MESSAGING_SENDER_ID',
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'));
  static String get firebaseAppId =>
      _get('FIREBASE_APP_ID', const String.fromEnvironment('FIREBASE_APP_ID'));

  // --- Google Sign In ---
  static String get googleServerClientId => _get('GOOGLE_SERVER_CLIENT_ID',
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'));

  // --- Stripe ---
  static String get stripePublishableKey => _get('STRIPE_PUBLISHABLE_KEY',
      const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY'));
  static String get stripeConnectClientId => _get('STRIPE_CONNECT_CLIENT_ID',
      const String.fromEnvironment('STRIPE_CONNECT_CLIENT_ID'));

  // --- Dev Toggles ---
  static bool get disableAuthGate {
    if (const bool.fromEnvironment('DISABLE_AUTH_GATE')) return true;
    return dotEnvValue('DISABLE_AUTH_GATE')?.toLowerCase() == 'true';
  }

  // --- Helper ---
  static String _get(String key, String buildTimeValue) {
    if (buildTimeValue.isNotEmpty) return buildTimeValue;
    return dotEnvValue(key) ?? '';
  }
}
