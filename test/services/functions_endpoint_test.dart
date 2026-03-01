import 'package:clutterzen/services/functions_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('FunctionsEndpoint.buildUri', () {
    test('normalizes slashes for base and endpoint path', () {
      final uri = FunctionsEndpoint.buildUri(
        baseUrl: 'https://example.com/api/',
        path: '/user/credits/consume/',
      );
      expect(
        uri.toString(),
        'https://example.com/api/user/credits/consume',
      );
    });

    test('throws config exception for empty base URL', () {
      expect(
        () => FunctionsEndpoint.buildUri(
          baseUrl: '',
          path: '/user/credits/consume',
        ),
        throwsA(isA<FunctionsConfigException>()),
      );
    });
  });

  group('FunctionsEndpoint error mapping', () {
    test('maps 404 HTML response to friendly endpoint message', () {
      final response = http.Response(
        '<html><head><title>404</title></head><body>not found</body></html>',
        404,
        headers: {'content-type': 'text/html'},
      );
      final exception = FunctionsEndpoint.buildRequestException(
        response: response,
        uri: Uri.parse('https://example.com/api/user/credits/consume'),
      );

      expect(exception.message, contains('Server endpoint not found (404)'));
      expect(exception.message.contains('<html>'), isFalse);
    });

    test('maps 401 to authentication message', () {
      final response = http.Response(
        '{"error":"invalid token"}',
        401,
        headers: {'content-type': 'application/json'},
      );
      final exception = FunctionsEndpoint.buildRequestException(
        response: response,
        uri: Uri.parse('https://example.com/api/user/credits/consume'),
      );

      expect(exception.message, 'Authentication failed. Please sign in again.');
    });

    test('maps 500 to temporary server message', () {
      final response = http.Response(
        '{"error":"internal error"}',
        500,
        headers: {'content-type': 'application/json'},
      );
      final exception = FunctionsEndpoint.buildRequestException(
        response: response,
        uri: Uri.parse('https://example.com/api/vision/analyze'),
      );

      expect(
        exception.message,
        'Server is temporarily unavailable (500). Please try again.',
      );
    });
  });
}
