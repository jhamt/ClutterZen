abstract class IGenerateProvider {
  Future<String> generateOrganizedImage({
    required String imageUrl,
    bool allowFallback = true,
  });
}
