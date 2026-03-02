import 'dart:convert';
import 'dart:typed_data';

import 'package:clutterzen/services/firebase_functions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FirebaseFunctionsService.getGeminiRecommendationsViaFunction', () {
    test('sends extended recommendation context fields', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'summary': 'Detailed plan summary',
              'services': [],
              'products': [],
              'diyPlan': [
                {
                  'stepNumber': 1,
                  'title': 'Step',
                  'description': 'Objective and verification present.',
                  'tips': ['Tip 1', 'Tip 2'],
                }
              ],
              'meta': {
                'source': 'ai',
                'qualityPassed': true,
                'model': 'gemini-3-pro-preview',
              },
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final recommendation = await service.getGeminiRecommendationsViaFunction(
        spaceDescription: 'Workspace with mixed clutter',
        detectedObjects: ['laptop', 'cable', 'paper'],
        clutterScore: 58,
        labels: ['messy', 'office'],
        objectDetections: [
          {
            'name': 'laptop',
            'confidence': 0.9,
            'box': {'left': 0.1, 'top': 0.2, 'width': 0.3, 'height': 0.2},
          }
        ],
        zoneHotspots: [
          {
            'name': 'upper-right',
            'objectCount': 4,
            'dominantItems': ['paper'],
            'box': {'left': 0.4, 'top': 0.1, 'width': 0.4, 'height': 0.4},
          }
        ],
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/scan.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        localeCode: 'en',
        detailLevel: 'balanced',
      );

      expect(
          capturedUri.toString(), 'https://example.com/api/gemini/recommend');
      expect(capturedBody['spaceDescription'], isNotNull);
      expect(capturedBody['detectedObjects'], isA<List<dynamic>>());
      expect(capturedBody['labels'], isA<List<dynamic>>());
      expect(capturedBody['objectDetections'], isA<List<dynamic>>());
      expect(capturedBody['zoneHotspots'], isA<List<dynamic>>());
      expect(capturedBody['imageUrl'], isA<String>());
      expect(capturedBody['imageBase64'], isA<String>());
      expect(capturedBody['localeCode'], 'en');
      expect(capturedBody['detailLevel'], 'balanced');
      expect(recommendation.diyPlan, isNotEmpty);
      expect(recommendation.meta?.source, 'ai');
    });

    test('remains backward compatible with minimal fields', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'summary': 'Fallback summary',
              'services': [],
              'products': [],
              'diyPlan': [],
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final recommendation = await service.getGeminiRecommendationsViaFunction(
        detectedObjects: ['book'],
      );

      expect(recommendation.summary, isNotNull);
      expect(recommendation.diyPlan, isEmpty);
    });

    test('retries once on 401 and succeeds', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'error': 'Invalid or expired token'}),
            401,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'summary': 'Recovered after token refresh',
              'services': [],
              'products': [],
              'diyPlan': [
                {
                  'stepNumber': 1,
                  'title': 'Reset zone',
                  'description': 'Objective, action, and verification details.',
                  'tips': ['Tip 1', 'Tip 2'],
                }
              ],
              'meta': {
                'source': 'ai_retry',
                'qualityPassed': true,
                'model': 'gemini-3-flash-preview',
              },
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final recommendation = await service.getGeminiRecommendationsViaFunction(
        detectedObjects: ['desk', 'paper'],
      );

      expect(requestCount, 2);
      expect(recommendation.summary, contains('Recovered'));
      expect(recommendation.diyPlan, isNotEmpty);
      expect(recommendation.meta?.source, 'ai_retry');
    });
  });

  group('FirebaseFunctionsService.getNearbyProfessionalsViaFunction', () {
    test('sends location and context payload, parses normalized services',
        () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'services': [
                {
                  'id': 'place_1',
                  'name': 'City Organizer Co',
                  'specialty': 'Home office and desk organization',
                  'rating': 4.7,
                  'ratePerHour': 52,
                  'phone': '+1 212 555 2100',
                  'email': null,
                  'serviceAreas': ['Residential', 'Workspaces'],
                  'description': 'Verified local organizer',
                  'experienceYears': 5,
                  'website': 'https://example.com',
                  'imageUrl': 'https://example.com/photo.jpg',
                  'stripeAccountId': null,
                  'address': 'New York, NY',
                  'distanceMeters': 2300,
                  'mapsUrl': 'https://maps.google.com/?q=place_1',
                  'placeId': 'place_1',
                  'verifiedSource': 'google_places',
                  'isOperational': true,
                  'userRatingsTotal': 120,
                }
              ],
              'meta': {
                'source': 'google_places',
                'radiusMeters': 15000,
                'resolvedLocation': {
                  'source': 'gps',
                  'latitude': 40.71,
                  'longitude': -74.0,
                },
                'quality': {
                  'candidateCount': 40,
                  'trustedCount': 12,
                  'returnedCount': 8,
                }
              },
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final result = await service.getNearbyProfessionalsViaFunction(
        detectedObjects: ['desk', 'cable'],
        labels: ['office'],
        clutterScore: 56,
        latitude: 40.7128,
        longitude: -74.0060,
        localeCode: 'en',
      );

      expect(capturedUri.toString(),
          'https://example.com/api/professionals/nearby');
      expect(capturedBody['latitude'], isNotNull);
      expect(capturedBody['longitude'], isNotNull);
      expect(capturedBody['detectedObjects'], isA<List<dynamic>>());
      expect(capturedBody['labels'], isA<List<dynamic>>());
      expect(capturedBody['radiusMeters'], 15000);
      expect(result.services, hasLength(1));
      expect(result.services.first.placeId, 'place_1');
      expect(result.meta?.source, 'google_places');
    });

    test('supports manual location query fallback', () async {
      late Map<String, dynamic> capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'services': [],
              'meta': {
                'source': 'google_places',
                'reason': 'no_verified_results'
              },
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final result = await service.getNearbyProfessionalsViaFunction(
        detectedObjects: const [],
        locationQuery: 'Austin, TX',
      );

      expect(capturedBody['locationQuery'], 'Austin, TX');
      expect(capturedBody['latitude'], isNull);
      expect(capturedBody['longitude'], isNull);
      expect(result.services, isEmpty);
      expect(result.meta?.reason, 'no_verified_results');
    });
  });

  group('FirebaseFunctionsService.getGeminiScanTitleViaFunction', () {
    test('sends image/context payload and parses title', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'title': 'Desk Cable Reset',
              'source': 'ai',
              'model': 'gemini-3-pro-preview',
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final title = await service.getGeminiScanTitleViaFunction(
        detectedObjects: ['desk', 'cable', 'paper'],
        labels: ['workspace', 'messy'],
        objectDetections: [
          {
            'name': 'desk',
            'confidence': 0.91,
            'box': {'left': 0.1, 'top': 0.2, 'width': 0.5, 'height': 0.4},
          }
        ],
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/demo/o/scan.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        localeCode: 'en',
      );

      expect(
          capturedUri.toString(), 'https://example.com/api/gemini/scan-title');
      expect(capturedBody['detectedObjects'], isA<List<dynamic>>());
      expect(capturedBody['labels'], isA<List<dynamic>>());
      expect(capturedBody['objectDetections'], isA<List<dynamic>>());
      expect(capturedBody['imageUrl'], isA<String>());
      expect(capturedBody['imageBase64'], isA<String>());
      expect(capturedBody['localeCode'], 'en');
      expect(title, 'Desk Cable Reset');
    });

    test('retries once on 401 and succeeds', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'error': 'Invalid or expired token'}),
            401,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {
              'title': 'Kitchen Counter Reset',
              'source': 'ai_retry',
              'model': 'gemini-3-flash-preview',
            }
          }),
          200,
        );
      });

      final service = FirebaseFunctionsService(
        client: mockClient,
        functionsUrl: 'https://example.com/api',
      );

      final title = await service.getGeminiScanTitleViaFunction(
        detectedObjects: ['kitchen', 'plate'],
      );

      expect(requestCount, 2);
      expect(title, 'Kitchen Counter Reset');
    });
  });
}
