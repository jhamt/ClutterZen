import 'dart:typed_data';

import '../../models/vision_models.dart';
import '../interfaces/vision_provider.dart';
import '../interfaces/generate_provider.dart';
import '../../services/firebase_functions_service.dart';

/// Vision provider that uses Firebase Cloud Functions
class FirebaseFunctionsVisionProvider implements IVisionProvider {
  FirebaseFunctionsVisionProvider({
    FirebaseFunctionsService? service,
  }) : _service = service ?? FirebaseFunctionsService();

  final FirebaseFunctionsService _service;

  @override
  Future<VisionAnalysis> analyzeImageBytes(Uint8List bytes) async {
    return _service.analyzeImageViaFunction(imageBytes: bytes);
  }

  @override
  Future<VisionAnalysis> analyzeImageUrl(String imageUrl) async {
    return _service.analyzeImageViaFunction(imageUrl: imageUrl);
  }
}

/// Generate provider that uses Firebase Cloud Functions
class FirebaseFunctionsGenerateProvider implements IGenerateProvider {
  FirebaseFunctionsGenerateProvider({
    FirebaseFunctionsService? service,
  }) : _service = service ?? FirebaseFunctionsService();

  final FirebaseFunctionsService _service;

  @override
  Future<String> generateOrganizedImage({
    required String imageUrl,
    bool allowFallback = true,
  }) async {
    return _service.generateOrganizedImageViaFunction(imageUrl: imageUrl);
  }
}
