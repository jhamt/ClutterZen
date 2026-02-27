import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/gemini_models.dart';

/// Service for interacting with Google Gemini AI API.
/// Provides smart recommendations based on detected objects and space analysis.
class GeminiService {
  GeminiService({required String apiKey}) : _apiKey = apiKey;

  final String _apiKey;
  // Prioritized text models for recommendations.
  static const List<String> _textModelHierarchy = [
    'gemini-3-pro-preview', // Primary: Latest Pro (High Intelligence)
    'gemini-3-flash-preview', // Fallback 1: Latest Flash (Speed/Efficiency)
    'gemini-2.5-flash-lite', // Fallback 2: Lower latency/cost
    'gemini-2.5-flash', // Fallback 3: Broadly available
  ];

  // Prioritized image-capable models for organized image fallback.
  static const List<String> _imageModelHierarchy = [
    'nano-banana-pro-preview',
    'gemini-3-pro-image-preview',
    'gemini-2.5-flash-image',
  ];

  /// Analyzes detected objects and returns recommendations.
  Future<GeminiRecommendation> getRecommendations({
    String? spaceDescription,
    required List<String> detectedObjects,
    Uint8List? imageBytes,
    double? clutterScore,
  }) async {
    if (detectedObjects.isEmpty && spaceDescription == null) {
      return GeminiRecommendation.empty();
    }

    final prompt = _buildPrompt(
      spaceDescription: spaceDescription,
      detectedObjects: detectedObjects,
      clutterScore: clutterScore,
    );

    for (final modelName in _textModelHierarchy) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.7,
            maxOutputTokens: 2048,
            responseMimeType: 'application/json',
          ),
        );

        final content = <Content>[];
        if (imageBytes != null) {
          content.add(Content.multi([
            DataPart('image/jpeg', imageBytes),
            TextPart(prompt),
          ]));
        } else {
          content.add(Content.text(prompt));
        }

        // Try to generate content with the current model
        final response = await model.generateContent(content);
        final text = response.text;

        if (text != null && text.isNotEmpty) {
          // If successful, parse and return immediately
          return _parseResponse(text);
        }
      } catch (e) {
        debugPrint('Gemini text model failed ($modelName): $e');
        continue;
      }
    }

    // If all models fail, return empty fallback
    return GeminiRecommendation(
      services: [],
      products: [],
      diyPlan: [],
      summary: 'Unable to generate recommendations from any AI model.',
    );
  }

  /// Generates an image using Gemini image-capable models as a fallback.
  ///
  /// Tries Nano Banana first when available, then other image models.
  Future<Uint8List?> generateImageFallback(String prompt) async {
    for (final modelName in _imageModelHierarchy) {
      try {
        final bytes = await _generateImageWithModel(
          modelName: modelName,
          prompt: prompt,
        );
        if (bytes != null && bytes.isNotEmpty) {
          debugPrint('Gemini image generation succeeded with $modelName');
          return bytes;
        }
      } catch (e) {
        debugPrint('Gemini image model failed ($modelName): $e');
      }
    }
    return null;
  }

  Future<Uint8List?> _generateImageWithModel({
    required String modelName,
    required String prompt,
  }) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE']
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractInlineImageBytes(data);
      } else {
        debugPrint(
            'Gemini image model $modelName error (${response.statusCode}): ${_preview(response.body)}');
      }
      return null;
    } catch (e) {
      debugPrint('Gemini image request exception ($modelName): $e');
      return null;
    }
  }

  Uint8List? _extractInlineImageBytes(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    for (final rawCandidate in candidates) {
      final candidate = rawCandidate as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? const [];
      for (final rawPart in parts) {
        final part = rawPart as Map<String, dynamic>;
        final dynamic inlineDataRaw =
            part['inlineData'] ?? part['inline_data'];
        if (inlineDataRaw is! Map<String, dynamic>) continue;

        final mimeType =
            (inlineDataRaw['mimeType'] ?? inlineDataRaw['mime_type'])
                ?.toString();
        final payload = inlineDataRaw['data']?.toString();
        if (payload == null || payload.isEmpty) continue;
        if (mimeType != null && !mimeType.startsWith('image/')) continue;
        try {
          return base64Decode(payload);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  String _preview(String body) {
    if (body.length <= 220) return body;
    return '${body.substring(0, 220)}...';
  }

  String _buildPrompt({
    String? spaceDescription,
    required List<String> detectedObjects,
    double? clutterScore,
  }) {
    final objectsList = detectedObjects.join(', ');

    // Smart room type detection
    final roomType = _detectRoomType(detectedObjects);
    final roomContext = _getRoomContext(roomType);

    // Clutter severity analysis
    final severity = _analyzeClutterSeverity(clutterScore ?? 50.0);

    return '''
You are a professional home organization expert specializing in ${roomType.toLowerCase()} spaces.

SPACE ANALYSIS:
${spaceDescription != null ? '- Description: $spaceDescription' : ''}
- Room Type: $roomType
- Detected Objects: $objectsList
- Clutter Level: ${severity.level} (${clutterScore?.toStringAsFixed(0) ?? '50'}/100)

${severity.context}

${roomContext.focus}

Provide recommendations in the following JSON format:
{
  "summary": "${severity.summaryGuideline}",
  "services": [
    {
      "name": "Service name",
      "description": "What this service does",
      "category": "${roomContext.serviceCategory}",
      "estimatedCost": 100
    }
  ],
  "products": [
    {
      "name": "Product name",
      "description": "How this product helps",
      "category": "${roomContext.productCategory}",
      "price": 25
    }
  ],
  "diyPlan": [
    {
      "stepNumber": 1,
      "title": "Step title",
      "description": "Detailed instructions",
      "tips": ["Helpful tip 1", "Helpful tip 2"]
    }
  ]
}

GUIDELINES:
${roomContext.guidelines}
${severity.recommendations}
''';
  }

  String _detectRoomType(List<String> objects) {
    final objectsLower = objects.map((o) => o.toLowerCase()).toSet();

    // Kitchen indicators
    if (objectsLower.any((o) => [
          'refrigerator',
          'stove',
          'microwave',
          'dishes',
          'utensils',
          'pots',
          'pans',
          'food',
          'kitchen'
        ].contains(o))) {
      return 'Kitchen';
    }

    // Bedroom indicators
    if (objectsLower.any((o) => [
          'bed',
          'mattress',
          'pillow',
          'blanket',
          'dresser',
          'nightstand',
          'closet',
          'clothes'
        ].contains(o))) {
      return 'Bedroom';
    }

    // Bathroom indicators
    if (objectsLower.any((o) => [
          'toilet',
          'sink',
          'shower',
          'bathtub',
          'towel',
          'soap',
          'shampoo',
          'bathroom'
        ].contains(o))) {
      return 'Bathroom';
    }

    // Garage/Storage indicators
    if (objectsLower.any((o) => [
          'tools',
          'car',
          'bike',
          'lawn',
          'garage',
          'workbench',
          'ladder',
          'paint'
        ].contains(o))) {
      return 'Garage/Storage';
    }

    // Office indicators
    if (objectsLower.any((o) => [
          'desk',
          'computer',
          'laptop',
          'monitor',
          'keyboard',
          'office',
          'chair',
          'papers',
          'documents'
        ].contains(o))) {
      return 'Office/Workspace';
    }

    // Living room indicators
    if (objectsLower.any((o) => [
          'couch',
          'sofa',
          'tv',
          'television',
          'coffee table',
          'remote',
          'living room'
        ].contains(o))) {
      return 'Living Room';
    }

    return 'General Space';
  }

  _RoomContext _getRoomContext(String roomType) {
    switch (roomType) {
      case 'Kitchen':
        return _RoomContext(
          focus:
              'FOCUS: Food safety, expiration management, and workflow efficiency.',
          serviceCategory: 'Kitchen Organization, Deep Cleaning, Pest Control',
          productCategory: 'Food Storage, Labels, Pantry Solutions',
          guidelines:
              '- Prioritize food storage containers and expiration tracking\n'
              '- Recommend space-saving solutions for small kitchens\n'
              '- Address hygiene and food safety in recommendations',
        );

      case 'Bedroom':
        return _RoomContext(
          focus:
              'FOCUS: Clothing management, sleep environment optimization, and personal item storage.',
          serviceCategory:
              'Closet Organization, Feng Shui Consultation, Moving Services',
          productCategory:
              'Closet Organizers, Under-bed Storage, Drawer Dividers',
          guidelines: '- Focus on wardrobe organization and seasonal rotation\n'
              '- Recommend sleep-friendly decluttering (minimal, calming)\n'
              '- Suggest privacy and personal space solutions',
        );

      case 'Garage/Storage':
        return _RoomContext(
          focus:
              'FOCUS: Heavy-duty storage, seasonal item management, and tool organization.',
          serviceCategory:
              'Garage Organization, Junk Removal, Handyman Services',
          productCategory:
              'Wall-mounted Systems, Weather-proof Bins, Tool Organizers',
          guidelines:
              '- Recommend wall-mounted and overhead storage to maximize floor space\n'
              '- Suggest heavy-duty, weather-resistant products\n'
              '- Address safety (sharp tools, chemicals) in organization plan',
        );

      case 'Office/Workspace':
        return _RoomContext(
          focus:
              'FOCUS: Productivity optimization, paper management, and tech organization.',
          serviceCategory:
              'Professional Organizing, Document Shredding, IT Cable Management',
          productCategory: 'Desk Organizers, Filing Systems, Cable Management',
          guidelines:
              '- Prioritize paper filing and digital organization tips\n'
              '- Recommend ergonomic and productivity-enhancing products\n'
              '- Address cable management and tech clutter',
        );

      case 'Bathroom':
        return _RoomContext(
          focus: 'FOCUS: Hygiene, moisture control, and small-space storage.',
          serviceCategory:
              'Deep Cleaning, Mold Remediation, Bathroom Remodeling',
          productCategory:
              'Shower Caddies, Medicine Cabinet Organizers, Moisture-proof Storage',
          guidelines: '- Recommend moisture-resistant storage solutions\n'
              '- Focus on hygiene and accessibility\n'
              '- Suggest space-saving vertical storage',
        );

      default:
        return _RoomContext(
          focus:
              'FOCUS: General organization principles and versatile solutions.',
          serviceCategory: 'Organization, Cleaning, Decluttering',
          productCategory: 'Storage, Labels, Containers',
          guidelines:
              '- Suggest 2-4 relevant services based on detected clutter\n'
              '- Recommend 3-6 products that would help organize the space\n'
              '- Create a 4-6 step DIY plan for self-organization',
        );
    }
  }

  _ClutterSeverity _analyzeClutterSeverity(double score) {
    if (score >= 80) {
      return _ClutterSeverity(
        level: 'SEVERE',
        context:
            'WARNING: This space is severely cluttered and may be overwhelming to tackle alone.',
        summaryGuideline:
            'Acknowledge the severity, recommend professional help first, then outline a phased approach',
        recommendations:
            '- STRONGLY recommend professional junk removal or organizer as first step\n'
            '- Break DIY plan into multiple phases (don\'t overwhelm)\n'
            '- Suggest hiring help for heavy lifting or disposal\n'
            '- Recommend "quick wins" to build motivation',
      );
    } else if (score >= 60) {
      return _ClutterSeverity(
        level: 'MODERATE-HIGH',
        context:
            'This space has significant clutter that will require dedicated effort to organize.',
        summaryGuideline:
            'Be realistic about time/effort needed, offer both DIY and professional options',
        recommendations:
            '- Provide both DIY solutions AND professional service options\n'
            '- Recommend time-saving products (pre-labeled bins, all-in-one systems)\n'
            '- Suggest tackling space in zones over multiple sessions\n'
            '- Include motivation tips in DIY plan',
      );
    } else if (score >= 40) {
      return _ClutterSeverity(
        level: 'MODERATE',
        context:
            'This space has manageable clutter that can be addressed with focused organization.',
        summaryGuideline:
            'Offer practical, actionable DIY solutions with minimal professional help',
        recommendations:
            '- Focus on practical DIY solutions that can be completed in one session\n'
            '- Recommend affordable, accessible products\n'
            '- Professional services are optional (mention as time-savers)\n'
            '- Provide clear, step-by-step instructions',
      );
    } else {
      return _ClutterSeverity(
        level: 'LIGHT',
        context:
            'This space is mostly organized and needs only minor improvements.',
        summaryGuideline:
            'Focus on maintenance, optimization, and finishing touches',
        recommendations:
            '- Suggest maintenance products (label makers, small containers)\n'
            '- Recommend aesthetic improvements (decorative baskets, matching bins)\n'
            '- Professional services likely not needed\n'
            '- DIY plan should focus on optimization, not overhaul',
      );
    }
  }

  GeminiRecommendation _parseResponse(String text) {
    try {
      // Clean up potential markdown code blocks
      var cleanText = text.trim();
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      }
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      cleanText = cleanText.trim();

      final json = jsonDecode(cleanText) as Map<String, dynamic>;

      final services = (json['services'] as List<dynamic>?)
              ?.map((s) =>
                  ServiceRecommendation.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      final products = (json['products'] as List<dynamic>?)
              ?.map((p) =>
                  ProductRecommendation.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];

      final diyPlan = (json['diyPlan'] as List<dynamic>?)
              ?.map((d) => DiyStep.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [];

      return GeminiRecommendation(
        services: services,
        products: products,
        diyPlan: diyPlan,
        summary: json['summary'] as String?,
      );
    } catch (e) {
      // Return empty on parse failure
      return GeminiRecommendation(
        services: [],
        products: [],
        diyPlan: [],
        summary: 'Unable to parse recommendations.',
      );
    }
  }
}

// Helper classes for room context
class _RoomContext {
  final String focus;
  final String serviceCategory;
  final String productCategory;
  final String guidelines;

  _RoomContext({
    required this.focus,
    required this.serviceCategory,
    required this.productCategory,
    required this.guidelines,
  });
}

class _ClutterSeverity {
  final String level;
  final String context;
  final String summaryGuideline;
  final String recommendations;

  _ClutterSeverity({
    required this.level,
    required this.context,
    required this.summaryGuideline,
    required this.recommendations,
  });
}
