import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_firebase.dart';
import 'env.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';
import 'services/crashlytics_service.dart';
import 'services/env_validator.dart';
import 'services/offline_queue_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env.public', isOptional: true);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Warning: Could not load env files: $e');
      debugPrint(
          'Continuing without env files (using environment variables or defaults)');
    }
  }

  // Validate environment configuration
  EnvValidator.performRuntimeCheck();

  try {
    final opts = DefaultFirebaseOptions.currentPlatformOrNull;
    if (opts != null) {
      await Firebase.initializeApp(options: opts);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization failed: $e');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(MyApp());

  // Perform non-UI-critical startup work in the background so first frame
  // appears immediately after runApp.
  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeBackgroundServices() async {
  // Initialize analytics and crash reporting after Firebase is ready.
  await AnalyticsService.initialize();
  await CrashlyticsService.initialize();

  // Initialize connectivity service and sync offline queue when online
  connectivityService.connectivityStream.listen((isConnected) {
    if (isConnected) {
      // Sync pending operations when connection is restored
      OfflineQueueService.syncPendingAnalyses().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error syncing offline queue: $e');
        }
      });
    }
  });

  try {
    final user = AppFirebase.auth.currentUser;
    if (user != null) {
      await CrashlyticsService.setUserId(user.uid);
      await AnalyticsService.setUserId(user.uid);
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Skipping user analytics/crashlytics setup: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  MyApp({super.key, bool? enableAuthGate, String? initialRoute})
      : _enableAuthGate = enableAuthGate ?? !Env.disableAuthGate,
        _initialRoute = initialRoute ?? '/onboarding';

  final bool _enableAuthGate;
  final String _initialRoute;

  @override
  Widget build(BuildContext context) {
    if (!_enableAuthGate) {
      return MaterialApp(
        title: 'Clutter Zen',
        theme: buildAppTheme(),
        routes: AppRoutes.routes,
        initialRoute: _initialRoute,
      );
    }

    return StreamBuilder<User?>(
      stream: AppFirebase.auth.authStateChanges(),
      builder: (context, snapshot) {
        // Update Crashlytics and Analytics user ID on auth state change
        final user = snapshot.data;
        if (user != null) {
          CrashlyticsService.setUserId(user.uid);
          AnalyticsService.setUserId(user.uid);
        } else {
          CrashlyticsService.setUserId(null);
          AnalyticsService.setUserId(null);
        }
        final route = snapshot.connectionState == ConnectionState.waiting
            ? '/splash'
            : snapshot.hasData
                ? '/home'
                : '/onboarding';

        return MaterialApp(
          key: ValueKey(route),
          title: 'Clutter Zen',
          theme: buildAppTheme(),
          routes: AppRoutes.routes,
          initialRoute: route,
        );
      },
    );
  }
}
