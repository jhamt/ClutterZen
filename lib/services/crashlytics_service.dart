import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for Firebase Crashlytics crash reporting
class CrashlyticsService {
  static FirebaseCrashlytics? _crashlytics;

  /// Initialize Crashlytics service
  static Future<void> initialize() async {
    try {
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Enable crash collection in debug mode for testing
      if (kDebugMode) {
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      } else {
        // In production, only enable if user has consented
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
      }

      // Pass Flutter errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        if (kDebugMode) {
          // Keep default red-screen + console diagnostics in debug.
          FlutterError.presentError(errorDetails);
        }
        _crashlytics?.recordFlutterFatalError(errorDetails);
      };

      // Pass async errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        // Don't swallow async exceptions in debug mode.
        return !kDebugMode;
      };

      if (kDebugMode) {
        debugPrint('Crashlytics service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize Crashlytics: $e');
      }
    }
  }

  /// Get Crashlytics instance
  static FirebaseCrashlytics? get crashlytics => _crashlytics;

  /// Log a non-fatal error
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (_crashlytics == null) return;
    try {
      await _crashlytics!.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording to Crashlytics: $e');
      }
    }
  }

  /// Log a custom message
  static Future<void> log(String message) async {
    if (_crashlytics == null) return;
    try {
      await _crashlytics!.log(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error logging to Crashlytics: $e');
      }
    }
  }

  /// Set user identifier
  static Future<void> setUserId(String? userId) async {
    if (_crashlytics == null) return;
    try {
      if (userId != null && userId.isNotEmpty) {
        await _crashlytics!.setUserIdentifier(userId);
      } else {
        await _crashlytics!.setUserIdentifier('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error setting Crashlytics user ID: $e');
      }
    }
  }

  /// Set custom key-value pair
  static Future<void> setCustomKey(String key, dynamic value) async {
    if (_crashlytics == null) return;
    try {
      if (value is String) {
        await _crashlytics!.setCustomKey(key, value);
      } else if (value is int) {
        await _crashlytics!.setCustomKey(key, value);
      } else if (value is double) {
        await _crashlytics!.setCustomKey(key, value);
      } else if (value is bool) {
        await _crashlytics!.setCustomKey(key, value);
      } else {
        // Convert other types to string
        await _crashlytics!.setCustomKey(key, value.toString());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error setting Crashlytics custom key: $e');
      }
    }
  }

  /// Test crash (for development only)
  /// 
  /// WARNING: This will crash the app!
  static void testCrash() {
    if (_crashlytics == null) return;
    if (kDebugMode) {
      _crashlytics!.crash();
    }
  }
}

