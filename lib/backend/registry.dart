import 'package:firebase_storage/firebase_storage.dart';

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
import 'dart:typed_data';
import 'interfaces/gemini_provider.dart';
import '../services/gemini_service.dart';
import '../models/gemini_models.dart';
import '../env.dart';

class BackendRegistry {
  BackendRegistry._();

  static IAnalysisRepository analysisRepository() {
    return FirebaseAnalysisRepository(AppFirebase.firestore);
  }

  static IStorageRepository storageRepository() {
    return FirebaseStorageRepository(FirebaseStorage.instance);
  }

  static IVisionProvider visionProvider() {
    final svc = FirebaseFunctionsService(
      functionsUrl:
          Env.firebaseFunctionsUrl.isEmpty ? null : Env.firebaseFunctionsUrl,
    );
    return _FunctionsVisionAdapter(svc);
  }

  static IGenerateProvider generateProvider() {
    final svc = FirebaseFunctionsService(
      functionsUrl:
          Env.firebaseFunctionsUrl.isEmpty ? null : Env.firebaseFunctionsUrl,
    );
    return _FunctionsGenerateAdapter(svc);
  }

  static ILocalStore localStore() {
    return SharedPrefsStore();
  }

  static IGeminiProvider geminiProvider() {
    if (Env.geminiApiKey.isEmpty) {
      throw StateError(
          'GEMINI_API_KEY is not configured. Add it to your .env file.');
    }
    final svc = GeminiService(apiKey: Env.geminiApiKey);
    return _GeminiAdapter(svc);
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

class _FunctionsVisionAdapter implements IVisionProvider {
  _FunctionsVisionAdapter(this._svc);
  final FirebaseFunctionsService _svc;
  @override
  Future<VisionAnalysis> analyzeImageBytes(Uint8List bytes) =>
      _svc.analyzeImageViaFunction(imageBytes: bytes);
  @override
  Future<VisionAnalysis> analyzeImageUrl(String imageUrl) =>
      _svc.analyzeImageViaFunction(imageUrl: imageUrl);
}

class _FunctionsGenerateAdapter implements IGenerateProvider {
  _FunctionsGenerateAdapter(this._svc);
  final FirebaseFunctionsService _svc;
  @override
  Future<String> generateOrganizedImage({required String imageUrl}) async {
    try {
      return await _svc.generateOrganizedImageViaFunction(imageUrl: imageUrl);
    } catch (e) {
      // Replicate failed or quota exceeded, try Gemini fallback
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

class _GeminiAdapter implements IGeminiProvider {
  _GeminiAdapter(this._svc);
  final GeminiService _svc;
  @override
  Future<GeminiRecommendation> getRecommendations({
    String? spaceDescription,
    required List<String> detectedObjects,
    Uint8List? imageBytes,
    double? clutterScore,
  }) =>
      _svc.getRecommendations(
        spaceDescription: spaceDescription,
        detectedObjects: detectedObjects,
        imageBytes: imageBytes,
        clutterScore: clutterScore,
      );

  @override
  Future<Uint8List?> generateImageFallback(String prompt) =>
      _svc.generateImageFallback(prompt);
}
