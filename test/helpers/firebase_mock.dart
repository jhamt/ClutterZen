// Mock Firebase setup for testing
// This file sets up Firebase mocks so widget tests don't crash

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Callback = void Function(MethodCall call);

void setupFirebaseCoreMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupMethodChannelMocks();
}

void _setupMethodChannelMocks() {
  // Mock Firebase Core using Pigeon's channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
    (ByteData? message) async {
      // Return empty success response
      return _createPigeonResponse([
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': 'fake-api-key',
            'appId': 'fake-app-id',
            'messagingSenderId': 'fake-sender-id',
            'projectId': 'fake-project-id',
            'storageBucket': 'fake-bucket',
          },
          'pluginConstants': <String, dynamic>{},
        }
      ]);
    },
  );

  // Also mock the legacy MethodChannel approach as fallback
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_core'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Firebase#initializeCore') {
        return [
          {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'fake-api-key',
              'appId': 'fake-app-id',
              'messagingSenderId': 'fake-sender-id',
              'projectId': 'fake-project-id',
            },
            'pluginConstants': {},
          }
        ];
      }

      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': methodCall.arguments['appName'],
          'options': methodCall.arguments['options'],
          'pluginConstants': {},
        };
      }

      return null;
    },
  );

  // Mock Firebase Auth
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_auth'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Auth#registerIdTokenListener' ||
          methodCall.method == 'Auth#registerAuthStateListener') {
        return 0;
      }
      return null;
    },
  );

  // Mock connectivity_plus plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi']; // Return connected via wifi
      }
      return null;
    },
  );

  // Mock connectivity status channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    (MethodCall methodCall) async {
      return null;
    },
  );
}

ByteData _createPigeonResponse(dynamic result) {
  // Simple encoding for Pigeon response - just return empty success
  final codec = const StandardMessageCodec();
  return codec.encodeMessage(<dynamic>[result])!;
}
