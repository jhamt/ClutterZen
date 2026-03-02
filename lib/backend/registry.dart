import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../app_firebase.dart';
import 'interfaces/analysis_repository.dart';
import 'interfaces/storage_repository.dart';
import 'interfaces/vision_provider.dart';
import 'interfaces/generate_provider.dart';
import 'firebase/firebase_analysis_repository.dart';
import 'firebase/firebase_storage_repository.dart';
import '../models/vision_models.dart';
import '../services/firebase_functions_service.dart';
import 'interfaces/local_store.dart';
import 'local/shared_prefs_store.dart';
import 'interfaces/gemini_provider.dart';
import '../services/gemini_service.dart';
import '../models/gemini_models.dart';
import '../env.dart';
import '../services/vision_service.dart';
import '../services/replicate_service.dart';

class BackendRegistry {
  BackendRegistry._();

  static IAnalysisRepository analysisRepository() {
    return FirebaseAnalysisRepository(AppFirebase.firestore);
  }

  static IStorageRepository storageRepository() {
    return FirebaseStorageRepository(FirebaseStorage.instance);
  }

  static IVisionProvider visionProvider() {
    final functionsSvc = FirebaseFunctionsService(
      functionsUrl:
          Env.firebaseFunctionsUrl.isEmpty ? null : Env.firebaseFunctionsUrl,
    );
    final allowDirectFallback = kDebugMode &&
        (Env.dotEnvValue('ALLOW_CLIENT_AI_FALLBACK')?.toLowerCase() == 'true');
    final directSvc = allowDirectFallback && Env.visionApiKey.isNotEmpty
        ? VisionService(apiKey: Env.visionApiKey)
        : null;
    return _ResilientVisionAdapter(
      functionsSvc: functionsSvc,
      directSvc: directSvc,
    );
  }

  static IGenerateProvider generateProvider() {
    final functionsSvc = FirebaseFunctionsService(
      functionsUrl:
          Env.firebaseFunctionsUrl.isEmpty ? null : Env.firebaseFunctionsUrl,
    );
    final allowDirectFallback = kDebugMode &&
        (Env.dotEnvValue('ALLOW_CLIENT_AI_FALLBACK')?.toLowerCase() == 'true');
    final directSvc = !allowDirectFallback || Env.replicateToken.isEmpty
        ? null
        : ReplicateService(apiToken: Env.replicateToken);
    return _FunctionsGenerateAdapter(
      functionsSvc: functionsSvc,
      directSvc: directSvc,
    );
  }

  static ILocalStore localStore() {
    return SharedPrefsStore();
  }

  static IGeminiProvider geminiProvider() {
    final functionsSvc = FirebaseFunctionsService(
      functionsUrl:
          Env.firebaseFunctionsUrl.isEmpty ? null : Env.firebaseFunctionsUrl,
    );
    final allowDirectFallback = kDebugMode &&
        (Env.dotEnvValue('ALLOW_CLIENT_AI_FALLBACK')?.toLowerCase() == 'true');
    final directSvc = !allowDirectFallback || Env.geminiApiKey.isEmpty
        ? null
        : GeminiService(apiKey: Env.geminiApiKey);
    return _FunctionsGeminiAdapter(
      functionsSvc: functionsSvc,
      directSvc: directSvc,
    );
  }
}

// Registry class for easy access to services
class Registry {
  static IAnalysisRepository? _analysis;
  static IStorageRepository? _storage;
  static IVisionProvider? _vision;
  static IGenerateProvider? _replicate;
  static IGeminiProvider? _gemini;

  static IAnalysisRepository get analysis =>
      _analysis ??= BackendRegistry.analysisRepository();
  static IStorageRepository get storage =>
      _storage ??= BackendRegistry.storageRepository();
  static IVisionProvider get vision =>
      _vision ??= BackendRegistry.visionProvider();
  static IGenerateProvider get replicate =>
      _replicate ??= BackendRegistry.generateProvider();
  static IGeminiProvider get gemini =>
      _gemini ??= BackendRegistry.geminiProvider();

  static void configure({
    IAnalysisRepository? analysis,
    IStorageRepository? storage,
    IVisionProvider? vision,
    IGenerateProvider? replicate,
    IGeminiProvider? gemini,
  }) {
    if (analysis != null) _analysis = analysis;
    if (storage != null) _storage = storage;
    if (vision != null) _vision = vision;
    if (replicate != null) _replicate = replicate;
    if (gemini != null) _gemini = gemini;
  }

  static void reset() {
    _analysis = null;
    _storage = null;
    _vision = null;
    _replicate = null;
    _gemini = null;
  }
}

class _ResilientVisionAdapter implements IVisionProvider {
  _ResilientVisionAdapter({
    required FirebaseFunctionsService functionsSvc,
    required VisionService? directSvc,
  })  : _functionsSvc = functionsSvc,
        _directSvc = directSvc;

  final FirebaseFunctionsService _functionsSvc;
  final VisionService? _directSvc;

  @override
  Future<VisionAnalysis> analyzeImageBytes(Uint8List bytes) async {
    try {
      return await _functionsSvc.analyzeImageViaFunction(imageBytes: bytes);
    } catch (_) {
      final direct = _directSvc;
      if (direct == null) rethrow;
      return direct.analyzeImageBytes(bytes);
    }
  }

  @override
  Future<VisionAnalysis> analyzeImageUrl(String imageUrl) async {
    try {
      return await _functionsSvc.analyzeImageViaFunction(imageUrl: imageUrl);
    } catch (_) {
      final direct = _directSvc;
      if (direct == null) rethrow;
      return direct.analyzeImageUrl(imageUrl);
    }
  }
}

class _FunctionsGenerateAdapter implements IGenerateProvider {
  _FunctionsGenerateAdapter({
    required FirebaseFunctionsService functionsSvc,
    required ReplicateService? directSvc,
  })  : _functionsSvc = functionsSvc,
        _directSvc = directSvc;

  final FirebaseFunctionsService _functionsSvc;
  final ReplicateService? _directSvc;

  @override
  Future<String> generateOrganizedImage({
    required String imageUrl,
    bool allowFallback = true,
  }) async {
    if (!allowFallback) {
      // Strict mode for manual regenerate actions.
      return _functionsSvc.generateOrganizedImageViaFunction(
        imageUrl: imageUrl,
      );
    }

    try {
      return await _functionsSvc.generateOrganizedImageViaFunction(
        imageUrl: imageUrl,
      );
    } catch (e) {
      // Firebase Function unavailable/failed. Try direct Replicate client if available.
      final direct = _directSvc;
      if (direct != null) {
        try {
          return await direct.generateOrganizedImage(
            imageUrl: imageUrl,
            fallbackToOriginal: false,
          );
        } catch (_) {
          // Continue to Gemini fallback.
        }
      }

      // Replicate failed or quota exceeded, try Gemini fallback.
      try {
        final prompt =
            'A perfectly organized, clean and tidy version of this space, high quality, photorealistic interior design';
        final fallbackBytes =
            await Registry.gemini.generateImageFallback(prompt);
        if (fallbackBytes != null) {
          // Upload to Firebase Storage
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'fallback_images/organized_$timestamp.jpg';
          final fallbackUrl = await Registry.storage.uploadBytes(
            path: fileName,
            data: fallbackBytes,
            contentType: 'image/jpeg',
          );
          return fallbackUrl;
        }
      } catch (_) {
        // Ignore fallback errors and return original
      }

      // Non-blocking fallback to original image keeps the UX usable even when
      // the generation proxy is unavailable.
      return imageUrl;
    }
  }
}

class _FunctionsGeminiAdapter implements IGeminiProvider {
  _FunctionsGeminiAdapter({
    required FirebaseFunctionsService functionsSvc,
    required GeminiService? directSvc,
  })  : _functionsSvc = functionsSvc,
        _directSvc = directSvc;

  final FirebaseFunctionsService _functionsSvc;
  final GeminiService? _directSvc;

  @override
  Future<GeminiRecommendation> getRecommendations({
    String? spaceDescription,
    required List<String> detectedObjects,
    Uint8List? imageBytes,
    double? clutterScore,
    List<String>? labels,
    List<Map<String, dynamic>>? objectDetections,
    List<Map<String, dynamic>>? zoneHotspots,
    String? imageUrl,
    String? localeCode,
    String detailLevel = 'balanced',
  }) async {
    try {
      return await _functionsSvc.getGeminiRecommendationsViaFunction(
        spaceDescription: spaceDescription,
        detectedObjects: detectedObjects,
        clutterScore: clutterScore,
        labels: labels,
        objectDetections: objectDetections,
        zoneHotspots: zoneHotspots,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        localeCode: localeCode,
        detailLevel: detailLevel,
      );
    } catch (_) {
      final direct = _directSvc;
      if (direct == null) return GeminiRecommendation.empty();
      return direct.getRecommendations(
        spaceDescription: spaceDescription,
        detectedObjects: detectedObjects,
        imageBytes: imageBytes,
        clutterScore: clutterScore,
        labels: labels,
        objectDetections: objectDetections,
        zoneHotspots: zoneHotspots,
        imageUrl: imageUrl,
        localeCode: localeCode,
        detailLevel: detailLevel,
      );
    }
  }

  @override
  Future<String> generateScanTitle({
    required List<String> detectedObjects,
    List<String>? labels,
    List<Map<String, dynamic>>? objectDetections,
    String? imageUrl,
    Uint8List? imageBytes,
    String? localeCode,
  }) async {
    try {
      return await _functionsSvc.getGeminiScanTitleViaFunction(
        detectedObjects: detectedObjects,
        labels: labels,
        objectDetections: objectDetections,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        localeCode: localeCode,
      );
    } catch (_) {
      final direct = _directSvc;
      if (direct != null) {
        try {
          return await direct.generateScanTitle(
            detectedObjects: detectedObjects,
            labels: labels,
            objectDetections: objectDetections,
            imageUrl: imageUrl,
            imageBytes: imageBytes,
            localeCode: localeCode,
          );
        } catch (_) {
          // Fall through to deterministic fallback title.
        }
      }
      return _buildFallbackScanTitle(
        detectedObjects: detectedObjects,
        labels: labels,
      );
    }
  }

  @override
  Future<Uint8List?> generateImageFallback(String prompt) async {
    try {
      final imageBytes =
          await _functionsSvc.generateGeminiImageFallbackViaFunction(
        prompt: prompt,
      );
      if (imageBytes != null && imageBytes.isNotEmpty) {
        return imageBytes;
      }
    } catch (_) {
      // Fall through to direct fallback.
    }

    final direct = _directSvc;
    if (direct == null) return null;
    return direct.generateImageFallback(prompt);
  }

  String _buildFallbackScanTitle({
    required List<String> detectedObjects,
    List<String>? labels,
  }) {
    final objects =
        detectedObjects.map((value) => value.toLowerCase()).toList();
    final safeLabels = (labels ?? const <String>[])
        .map((value) => value.toLowerCase())
        .toList();

    bool hasAny(List<String> tokens) {
      return objects.any((item) => tokens.any(item.contains)) ||
          safeLabels.any((item) => tokens.any(item.contains));
    }

    if (hasAny(['desk', 'workspace', 'laptop', 'monitor'])) {
      return 'Desk Reset Plan';
    }
    if (hasAny(['kitchen', 'plate', 'utensil', 'pan', 'counter'])) {
      return 'Kitchen Reset Plan';
    }
    if (hasAny(['closet', 'wardrobe', 'clothing', 'hanger', 'shoe'])) {
      return 'Closet Reset Plan';
    }
    if (hasAny(['garage', 'tool', 'storage'])) {
      return 'Garage Reset Plan';
    }
    if (hasAny(['bathroom', 'sink', 'toilet', 'shower'])) {
      return 'Bathroom Reset Plan';
    }

    final primary = objects.isNotEmpty
        ? objects.first.replaceAll(RegExp(r'[_-]+'), ' ')
        : (safeLabels.isNotEmpty ? safeLabels.first : 'space');
    final normalized = primary
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    return normalized.isEmpty ? 'Space Reset Plan' : '$normalized Reset Plan';
  }
}
