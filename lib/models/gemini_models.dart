// Model classes for Gemini AI recommendations.

class GeminiRecommendation {
  final List<ServiceRecommendation> services;
  final List<ProductRecommendation> products;
  final List<DiyStep> diyPlan;
  final String? summary;
  final GeminiRecommendationMeta? meta;

  const GeminiRecommendation({
    required this.services,
    required this.products,
    required this.diyPlan,
    this.summary,
    this.meta,
  });

  factory GeminiRecommendation.empty() => const GeminiRecommendation(
        services: [],
        products: [],
        diyPlan: [],
      );

  factory GeminiRecommendation.fromJson(Map<String, dynamic> json) =>
      GeminiRecommendation(
        services: (json['services'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ServiceRecommendation.fromJson)
            .toList(),
        products: (json['products'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ProductRecommendation.fromJson)
            .toList(),
        diyPlan: (json['diyPlan'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DiyStep.fromJson)
            .toList(),
        summary: json['summary'] as String?,
        meta: json['meta'] is Map<String, dynamic>
            ? GeminiRecommendationMeta.fromJson(
                json['meta'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'services': services.map((s) => s.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'diyPlan': diyPlan.map((d) => d.toJson()).toList(),
        'summary': summary,
        'meta': meta?.toJson(),
      };
}

class GeminiRecommendationMeta {
  final String? source;
  final bool? qualityPassed;
  final String? model;

  const GeminiRecommendationMeta({
    this.source,
    this.qualityPassed,
    this.model,
  });

  factory GeminiRecommendationMeta.fromJson(Map<String, dynamic> json) =>
      GeminiRecommendationMeta(
        source: json['source'] as String?,
        qualityPassed: json['qualityPassed'] as bool?,
        model: json['model'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'qualityPassed': qualityPassed,
        'model': model,
      };
}

class ServiceRecommendation {
  final String name;
  final String description;
  final String category;
  final double? estimatedCost;

  const ServiceRecommendation({
    required this.name,
    required this.description,
    required this.category,
    this.estimatedCost,
  });

  factory ServiceRecommendation.fromJson(Map<String, dynamic> json) =>
      ServiceRecommendation(
        name: json['name'] as String? ?? 'Unknown Service',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category,
        'estimatedCost': estimatedCost,
      };
}

class ProductRecommendation {
  final String name;
  final String description;
  final String category;
  final double? price;
  final String? affiliateUrl;
  final String? imageUrl;

  const ProductRecommendation({
    required this.name,
    required this.description,
    required this.category,
    this.price,
    this.affiliateUrl,
    this.imageUrl,
  });

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) =>
      ProductRecommendation(
        name: json['name'] as String? ?? 'Unknown Product',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        price: (json['price'] as num?)?.toDouble(),
        affiliateUrl: json['affiliateUrl'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'affiliateUrl': affiliateUrl,
        'imageUrl': imageUrl,
      };
}

class DiyStep {
  final int stepNumber;
  final String title;
  final String description;
  final List<String> tips;

  const DiyStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.tips = const [],
  });

  factory DiyStep.fromJson(Map<String, dynamic> json) => DiyStep(
        stepNumber: json['stepNumber'] as int? ?? 0,
        title: json['title'] as String? ?? 'Step',
        description: json['description'] as String? ?? '',
        tips: (json['tips'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'title': title,
        'description': description,
        'tips': tips,
      };
}
