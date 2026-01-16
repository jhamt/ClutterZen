import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/services/contact_service.dart';

void main() {
  group('ContactService', () {
    test('should validate name requirement', () {
      expect(
        () => ContactService.submitContactForm(
          name: '',
          email: 'test@example.com',
          message: 'This is a test message with enough characters',
        ),
        throwsException,
      );
    });

    test('should validate email format', () {
      expect(
        () => ContactService.submitContactForm(
          name: 'Test User',
          email: 'invalid-email',
          message: 'This is a test message with enough characters',
        ),
        throwsException,
      );
    });

    test('should validate message length', () {
      expect(
        () => ContactService.submitContactForm(
          name: 'Test User',
          email: 'test@example.com',
          message: 'short',
        ),
        throwsException,
      );
    });
  });
}

