// Test setup helper
// Initializes all required bindings and mocks for tests

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_mock.dart';

/// Call this at the start of tests that need Firebase or dotenv
Future<void> setupTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  // Use testLoad for test environment
  // This loads from a string instead of file
  dotenv.testLoad(fileInput: '''
GEMINI_API_KEY=test_key
VISION_API_KEY=test_key
STRIPE_PUBLISHABLE_KEY=test_key
STRIPE_SECRET_KEY=test_key
REPLICATE_API_TOKEN=test_key
''');
}

/// Call this for simple unit tests that just need the binding
void setupUnitTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}
