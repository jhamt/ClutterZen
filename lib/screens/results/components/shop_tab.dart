import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/registry.dart';
import '../../../models/product_recommendation.dart';
import '../../../models/vision_models.dart';
import '../../../services/product_recommendation_service.dart';

import '../../../services/i18n_service.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({super.key, required this.analysis, this.embedded = false});
  final VisionAnalysis analysis;
  final bool embedded;

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  late Future<List<ProductRecommendation>> _recommendationsFuture;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _loadAllRecommendations();
  }

  Future<List<ProductRecommendation>> _loadAllRecommendations() async {
    // Load both Firestore products and Gemini AI recommendations in parallel
    final results = await Future.wait([
      ProductRecommendationService.generateRecommendations(widget.analysis),
      _loadGeminiRecommendations(),
    ]);

    // Merge Firestore products with Gemini suggestions
    final firestoreProducts = results[0];
    final geminiProducts = results[1];

    // Deduplicate by name (prefer Firestore if duplicate)
    final Map<String, ProductRecommendation> productMap = {};
    for (final product in [...firestoreProducts, ...geminiProducts]) {
      productMap.putIfAbsent(product.name.toLowerCase(), () => product);
    }

    return productMap.values.toList();
  }

  Future<List<ProductRecommendation>> _loadGeminiRecommendations() async {
    try {
      // Calculate approximate clutter score from object count
      final clutterScore =
          (widget.analysis.objects.length * 10.0).clamp(0.0, 100.0);

      final geminiRecs = await Registry.gemini.getRecommendations(
        detectedObjects: widget.analysis.objects.map((o) => o.name).toList(),
        spaceDescription: 'Cluttered space with items needing organization',
        clutterScore: clutterScore,
      );

      // Convert Gemini ProductRecommendations to app's ProductRecommendation format
      return geminiRecs.products
          .map((geminiProduct) => ProductRecommendation(
                name: geminiProduct.name,
                price: geminiProduct.price ?? 0.0,
                merchant: I18nService.translate("AI Recommended"),
                category: geminiProduct.category,
                affiliateLink: geminiProduct.affiliateUrl ?? '',
                imageUrl: geminiProduct.imageUrl ?? '',
                rating: 4.5, // Default rating for AI recommendations
                description: geminiProduct.description,
              ))
          .toList();
    } catch (e) {
      // Silently fail if Gemini is unavailable
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductRecommendation>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                    '${I18nService.translate("Error loading products")}: ${snapshot.error}'),
              ],
            ),
          );
        }

        final allRecommendations = snapshot.data ?? [];
        final filtered = _filterProducts(allRecommendations);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _selectedCategory != null
                      ? I18nService.translate("No products match your search")
                      : I18nService.translate(
                          "No product recommendations available"),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_searchQuery.isNotEmpty || _selectedCategory != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = null;
                      });
                    },
                    child: Text(I18nService.translate("Clear filters")),
                  ),
              ],
            ),
          );
        }

        final grid = GridView.builder(
          padding: const EdgeInsets.all(8),
          shrinkWrap: widget.embedded,
          physics: widget.embedded
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final product = filtered[i];
            return _ProductCard(product: product);
          },
        );

        return Column(
          children: [
            // Search and filter bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: I18nService.translate("Search products..."),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: I18nService.translate("All"),
                          selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: I18nService.translate("Storage"),
                          selected: _selectedCategory == 'Storage',
                          onTap: () =>
                              setState(() => _selectedCategory = 'Storage'),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: I18nService.translate("Organizers"),
                          selected: _selectedCategory == 'Organizers',
                          onTap: () =>
                              setState(() => _selectedCategory = 'Organizers'),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: I18nService.translate("Furniture"),
                          selected: _selectedCategory == 'Furniture',
                          onTap: () =>
                              setState(() => _selectedCategory = 'Furniture'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.embedded) grid else Expanded(child: grid),
          ],
        );
      },
    );
  }

  List<ProductRecommendation> _filterProducts(
      List<ProductRecommendation> products) {
    var filtered = products;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }

    return filtered;
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final ProductRecommendation product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.shopping_bag,
                              size: 48, color: Colors.grey),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.shopping_bag,
                          size: 48, color: Colors.grey),
                    ),
            ),
          ),
          // Product info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < product.rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          size: 12,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Name
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Expanded(
                    child: Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Price and merchant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        product.merchant,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Shop button
                  SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(product.affiliateLink),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: Text(I18nService.translate("Shop Now")),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}
