import '../models/product_recommendation.dart';
import '../models/vision_models.dart';

/// Service for generating product recommendations based on vision analysis
class ProductRecommendationService {
  /// Comprehensive product database organized by category
  static final Map<String, List<ProductRecommendation>> _productDatabase = {
    'clothing': [
      const ProductRecommendation(
        name: 'Slim Velvet Hangers 50-Pack',
        price: 29.99,
        merchant: 'Amazon',
        category: 'Hangers',
        affiliateLink: 'https://www.amazon.com/s?k=velvet+hangers+50+pack',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Slim+Velvet+Hangers',
        rating: 4.5,
        description: 'Space-saving velvet hangers for all clothing types',
      ),
      const ProductRecommendation(
        name: 'Drawer Divider Organizers Set',
        price: 15.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=drawer+dividers',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Drawer+Divider+Set',
        rating: 4.3,
        description: 'Adjustable dividers for drawers and shelves',
      ),
      const ProductRecommendation(
        name: 'Closet Storage Baskets Set',
        price: 24.99,
        merchant: 'Target',
        category: 'Storage',
        affiliateLink: 'https://www.target.com/s?searchTerm=closet+baskets',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Closet+Storage+Baskets',
        rating: 4.6,
        description: '6-piece fabric storage basket set',
      ),
    ],
    'electronics': [
      const ProductRecommendation(
        name: 'Cable Management Box',
        price: 19.99,
        merchant: 'Amazon',
        category: 'Cable Management',
        affiliateLink: 'https://www.amazon.com/s?k=cable+management+box',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Cable+Management+Box',
        rating: 4.6,
        description: 'Hide and organize all cables neatly',
      ),
      const ProductRecommendation(
        name: 'Desk Cable Organizer Clips',
        price: 12.99,
        merchant: 'Amazon',
        category: 'Cable Management',
        affiliateLink: 'https://www.amazon.com/s?k=cable+clips',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Desk+Cable+Organizer+Clips',
        rating: 4.4,
        description: 'Adhesive cable clips for desk organization',
      ),
      const ProductRecommendation(
        name: 'Tech Organizer Pouch',
        price: 16.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=tech+organizer+pouch',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Tech+Organizer+Pouch',
        rating: 4.5,
        description: 'Portable organizer for cables and accessories',
      ),
    ],
    'books_paper': [
      const ProductRecommendation(
        name: 'Desktop File Organizer',
        price: 22.99,
        merchant: 'Walmart',
        category: 'Filing',
        affiliateLink: 'https://www.walmart.com/search?q=file+organizer',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Desktop+File+Organizer',
        rating: 4.2,
        description: 'Multi-tier paper organizer for desk',
      ),
      const ProductRecommendation(
        name: 'Document Filing System',
        price: 34.99,
        merchant: 'Amazon',
        category: 'Filing',
        affiliateLink: 'https://www.amazon.com/s?k=document+filing+system',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Document+Filing+System',
        rating: 4.4,
        description: 'Expandable filing system with labels',
      ),
      const ProductRecommendation(
        name: 'Magazine Storage Boxes',
        price: 18.99,
        merchant: 'Target',
        category: 'Storage',
        affiliateLink: 'https://www.target.com/s?searchTerm=magazine+storage',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Magazine+Storage+Boxes',
        rating: 4.3,
        description: 'Set of 4 decorative storage boxes',
      ),
    ],
    'kitchen': [
      const ProductRecommendation(
        name: 'Airtight Food Storage Set',
        price: 32.99,
        merchant: 'Target',
        category: 'Storage',
        affiliateLink:
            'https://www.target.com/s?searchTerm=food+storage+containers',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Airtight+Food+Storage+Set',
        rating: 4.6,
        description: '14-piece container set with labels',
      ),
      const ProductRecommendation(
        name: 'Pantry Organizer Bins',
        price: 24.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=pantry+organizer',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Pantry+Organizer+Bins',
        rating: 4.5,
        description: 'Clear storage bins with labels',
      ),
      const ProductRecommendation(
        name: 'Spice Rack Organizer',
        price: 19.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=spice+rack',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Spice+Rack+Organizer',
        rating: 4.4,
        description: 'Tiered spice rack for cabinet',
      ),
    ],
    'office': [
      const ProductRecommendation(
        name: 'Desk Organizer Set',
        price: 28.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=desk+organizer',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Desk+Organizer+Set',
        rating: 4.5,
        description: 'Multi-compartment desk organizer',
      ),
      const ProductRecommendation(
        name: 'Pen and Pencil Holder',
        price: 14.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=pen+holder',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Pen+and+Pencil+Holder',
        rating: 4.3,
        description: 'Stylish desk accessory organizer',
      ),
    ],
    'furniture': [
      const ProductRecommendation(
        name: 'Storage Ottoman',
        price: 89.99,
        merchant: 'Amazon',
        category: 'Furniture',
        affiliateLink: 'https://www.amazon.com/s?k=storage+ottoman',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Storage+Ottoman',
        rating: 4.6,
        description: 'Multi-functional storage furniture',
      ),
      const ProductRecommendation(
        name: 'Shelf Organizer Bins',
        price: 16.99,
        merchant: 'Target',
        category: 'Organizers',
        affiliateLink: 'https://www.target.com/s?searchTerm=shelf+bins',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Shelf+Organizer+Bins',
        rating: 4.4,
        description: 'Bins for shelf organization',
      ),
    ],
    'toys': [
      const ProductRecommendation(
        name: 'Toy Storage Bins',
        price: 22.99,
        merchant: 'Target',
        category: 'Storage',
        affiliateLink: 'https://www.target.com/s?searchTerm=toy+storage',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Toy+Storage+Bins',
        rating: 4.5,
        description: 'Colorful storage bins for toys',
      ),
      const ProductRecommendation(
        name: 'Toy Organizer Cart',
        price: 39.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=toy+organizer',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Toy+Organizer+Cart',
        rating: 4.6,
        description: 'Rolling cart with multiple bins',
      ),
    ],
    'personal_care': [
      const ProductRecommendation(
        name: 'Bathroom Organizer Set',
        price: 24.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=bathroom+organizer',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Bathroom+Organizer',
        rating: 4.4,
        description: 'Shower and countertop organizers',
      ),
    ],
    'miscellaneous': [
      const ProductRecommendation(
        name: 'Storage Baskets Set',
        price: 19.99,
        merchant: 'Amazon',
        category: 'Storage',
        affiliateLink: 'https://www.amazon.com/s?k=storage+baskets',
        imageUrl:
            'https://placehold.co/400x300/111111/FFFFFF?text=Storage+Baskets+Set',
        rating: 4.3,
        description: 'Versatile storage solution',
      ),
      const ProductRecommendation(
        name: 'Label Maker',
        price: 29.99,
        merchant: 'Amazon',
        category: 'Organizers',
        affiliateLink: 'https://www.amazon.com/s?k=label+maker',
        imageUrl: 'https://placehold.co/400x300/111111/FFFFFF?text=Label+Maker',
        rating: 4.5,
        description: 'Portable label maker for organization',
      ),
    ],
  };

  /// Generates product recommendations based on detected objects
  static Future<List<ProductRecommendation>> generateRecommendations(
    VisionAnalysis analysis,
  ) async {
    final recommendations = <ProductRecommendation>[];
    final categoryScores = <String, double>{};
    final signalTokens = <String>[];

    // Count objects by category using confidence-weighted scores
    for (final obj in analysis.objects) {
      final category = _categorizeObject(obj.name);
      final confidenceWeight = obj.confidence.clamp(0.35, 1.0);
      categoryScores[category] =
          (categoryScores[category] ?? 0) + confidenceWeight;
      signalTokens.add(obj.name.toLowerCase());
    }

    // Also consider labels for broader recommendations
    for (final label in analysis.labels.take(8)) {
      final category = _categorizeObject(label);
      if (category != 'miscellaneous') {
        categoryScores[category] = (categoryScores[category] ?? 0) + 0.75;
      }
      signalTokens.add(label.toLowerCase());
    }

    final addedProducts = <String>{};
    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Keep miscellaneous as a fallback, not a primary recommendation source.
    final prioritizedCategories = sortedCategories
        .where((entry) => entry.key != 'miscellaneous')
        .toList();

    // Target a stable recommendation size based on detected signal richness.
    final targetCount = 6;

    // Get top category recommendations deterministically.
    for (final entry in prioritizedCategories.take(4)) {
      final category = entry.key;
      final score = entry.value;
      final categoryProducts = _productDatabase[category];

      if (categoryProducts != null && categoryProducts.isNotEmpty) {
        final productsToAdd = score >= 2.4 ? 2 : 1;
        final rankedProducts =
            List<ProductRecommendation>.from(categoryProducts)
              ..sort((a, b) {
                final scoreA = _scoreProduct(a, signalTokens);
                final scoreB = _scoreProduct(b, signalTokens);
                return scoreB.compareTo(scoreA);
              });

        for (int i = 0;
            i < productsToAdd &&
                i < rankedProducts.length &&
                recommendations.length < targetCount;
            i++) {
          final product = rankedProducts[i];
          if (addedProducts.add(product.name)) {
            recommendations.add(product);
          }
        }
      }
    }

    // Pull from secondary categories before using miscellaneous fallback.
    if (recommendations.length < targetCount) {
      for (final entry in sortedCategories) {
        if (recommendations.length >= targetCount) break;
        if (entry.key == 'miscellaneous' ||
            prioritizedCategories.any((cat) => cat.key == entry.key)) {
          continue;
        }
        final pool =
            _productDatabase[entry.key] ?? const <ProductRecommendation>[];
        for (final product in pool) {
          if (recommendations.length >= targetCount) break;
          if (addedProducts.add(product.name)) {
            recommendations.add(product);
          }
        }
      }
    }

    // If we still do not have enough, use miscellaneous products as fallback.
    if (recommendations.length < targetCount) {
      final generalProducts = _productDatabase['miscellaneous'] ?? [];
      for (final product
          in generalProducts.take(targetCount - recommendations.length)) {
        if (addedProducts.add(product.name)) {
          recommendations.add(product);
        }
      }
    }

    // Ensure minimum breadth even when signals are weak and miscellaneous has too few.
    if (recommendations.length < targetCount) {
      final allProducts = _productDatabase.values
          .expand((products) => products)
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final product in allProducts) {
        if (recommendations.length >= targetCount) break;
        if (addedProducts.add(product.name)) {
          recommendations.add(product);
        }
      }
    }

    // Final cap remains bounded and stable.
    return recommendations.take(targetCount).toList(growable: false);
  }

  static int _scoreProduct(
      ProductRecommendation product, List<String> signals) {
    final haystack =
        '${product.name} ${product.description} ${product.category}'
            .toLowerCase();
    int score = 0;
    for (final token in signals) {
      final normalized = token.trim();
      if (normalized.isEmpty) continue;
      if (haystack.contains(normalized)) {
        score += 2;
        continue;
      }
      final words = normalized.split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length < 3) continue;
        if (haystack.contains(word)) {
          score += 1;
        }
      }
    }
    return score;
  }

  /// Categorizes an object name into a product category
  static String _categorizeObject(String objectName) {
    final name = objectName.toLowerCase();

    if ([
      'shirt',
      'pants',
      'dress',
      'jacket',
      'coat',
      'shoe',
      'clothing',
      'jeans',
      'sweater',
      'sock',
      'tie',
      'belt',
      'hat',
      'scarf',
      'boot',
      'sneaker',
      'sandal',
      'shorts',
      'skirt',
      'blouse',
      't-shirt'
    ].any((item) => name.contains(item))) {
      return 'clothing';
    }

    if ([
      'book',
      'magazine',
      'newspaper',
      'paper',
      'document',
      'notebook',
      'folder',
      'binder',
      'journal',
      'letter',
      'envelope'
    ].any((item) => name.contains(item))) {
      return 'books_paper';
    }

    if ([
      'computer',
      'laptop',
      'phone',
      'tablet',
      'cable',
      'charger',
      'headphones',
      'keyboard',
      'mouse',
      'monitor',
      'television',
      'tv',
      'remote',
      'speaker',
      'printer',
      'camera'
    ].any((item) => name.contains(item))) {
      return 'electronics';
    }

    if ([
      'plate',
      'bowl',
      'cup',
      'mug',
      'glass',
      'fork',
      'spoon',
      'knife',
      'pot',
      'pan',
      'bottle',
      'food',
      'container',
      'jar',
      'can'
    ].any((item) => name.contains(item))) {
      return 'kitchen';
    }

    if ([
      'toy',
      'game',
      'doll',
      'puzzle',
      'ball',
      'lego',
      'stuffed animal',
      'action figure',
      'board game'
    ].any((item) => name.contains(item))) {
      return 'toys';
    }

    if ([
      'pen',
      'pencil',
      'stapler',
      'scissors',
      'tape',
      'ruler',
      'eraser',
      'paperclip',
      'calculator',
      'marker',
      'highlighter'
    ].any((item) => name.contains(item))) {
      return 'office';
    }

    if ([
      'towel',
      'brush',
      'cosmetics',
      'makeup',
      'perfume',
      'lotion',
      'shampoo',
      'soap',
      'toothbrush',
      'razor',
      'mirror'
    ].any((item) => name.contains(item))) {
      return 'personal_care';
    }

    if ([
      'chair',
      'table',
      'desk',
      'bed',
      'sofa',
      'couch',
      'shelf',
      'cabinet',
      'drawer',
      'dresser',
      'ottoman',
      'stool',
      'bench'
    ].any((item) => name.contains(item))) {
      return 'furniture';
    }

    return 'miscellaneous';
  }

  /// Gets all products for a specific category
  static List<ProductRecommendation> getProductsByCategory(String category) {
    return _productDatabase[category] ?? [];
  }

  /// Searches products by name or description
  static List<ProductRecommendation> searchProducts(String query) {
    final results = <ProductRecommendation>[];
    final lowerQuery = query.toLowerCase();

    for (final products in _productDatabase.values) {
      for (final product in products) {
        if (product.name.toLowerCase().contains(lowerQuery) ||
            product.description.toLowerCase().contains(lowerQuery) ||
            product.category.toLowerCase().contains(lowerQuery)) {
          results.add(product);
        }
      }
    }

    return results;
  }
}
