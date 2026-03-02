import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/product_recommendation.dart';
import '../../../models/vision_models.dart';
import '../../../services/i18n_service.dart';
import '../../../services/product_link_service.dart';
import '../../../services/product_recommendation_service.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({
    super.key,
    required this.analysis,
    this.embedded = false,
  });

  final VisionAnalysis analysis;
  final bool embedded;

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> with AutomaticKeepAliveClientMixin {
  static final Map<String, List<ProductRecommendation>> _cache =
      <String, List<ProductRecommendation>>{};
  static final Map<String, Future<List<ProductRecommendation>>> _pending =
      <String, Future<List<ProductRecommendation>>>{};

  late Future<List<ProductRecommendation>> _recommendationsFuture;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final cached = _cache[_cacheKey];
    _recommendationsFuture = cached != null
        ? Future<List<ProductRecommendation>>.value(cached)
        : _loadAllRecommendations();
  }

  String get _cacheKey {
    final objects = widget.analysis.objects
        .map((entry) => entry.name.toLowerCase().trim())
        .where((entry) => entry.isNotEmpty)
        .toList()
      ..sort();
    final labels = widget.analysis.labels
        .map((entry) => entry.toLowerCase().trim())
        .where((entry) => entry.isNotEmpty)
        .toList()
      ..sort();
    return 'shop|${objects.take(16).join(",")}|${labels.take(10).join(",")}';
  }

  @override
  bool get wantKeepAlive => true;

  Future<List<ProductRecommendation>> _loadAllRecommendations() async {
    final key = _cacheKey;
    final cached = _cache[key];
    if (cached != null) return cached;

    final inFlight = _pending[key];
    if (inFlight != null) return inFlight;

    // Curated-only recommendations for consistent trust and link accuracy.
    final future = ProductRecommendationService.generateRecommendations(
      widget.analysis,
    );
    _pending[key] = future;
    try {
      final result = await future;
      _cache[key] = result;
      return result;
    } finally {
      _pending.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  '${I18nService.translate("Error loading products")}: ${snapshot.error}',
                ),
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
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
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
            childAspectRatio: 0.58,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final product = filtered[i];
            return _ProductCard(product: product);
          },
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
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
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((product) => product.category == _selectedCategory)
          .toList();
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
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: _ProductImage(product: product),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                ProductLinkService.deriveMerchantLabel(
                                    product.affiliateLink),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl(context, product.affiliateLink),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
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
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String rawUrl) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = ProductLinkService.parseHttpUri(rawUrl);
    if (uri == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(I18nService.translate("Invalid product link.")),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    messenger?.showSnackBar(
      SnackBar(
        content: Text(I18nService.translate("Unable to open product link.")),
        duration: const Duration(seconds: 2),
      ),
    );
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
    final selectedTextColor = selected ? Colors.white : const Color(0xFF344054);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF111111),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selectedTextColor,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: Color(0xFFD0D5DD)),
      backgroundColor: const Color(0xFFF2F4F7),
    );
  }
}

class _ProductImage extends StatefulWidget {
  const _ProductImage({required this.product});

  final ProductRecommendation product;

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  int _attemptIndex = 0;

  List<String> get _candidates {
    final base = widget.product.imageUrl.trim();
    final normalizedBase =
        (base.isNotEmpty && ProductLinkService.parseHttpUri(base) != null)
            ? base
            : '';
    return <String>{
      if (normalizedBase.isNotEmpty) normalizedBase,
    }.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final urls = _candidates;
    if (_attemptIndex >= urls.length) {
      return _LocalProductPlaceholder(product: widget.product);
    }

    final url = urls[_attemptIndex];
    return Image.network(
      key: ValueKey(url),
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[500],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (_attemptIndex < urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _attemptIndex += 1);
          });
        }
        return _LocalProductPlaceholder(product: widget.product);
      },
    );
  }
}

class _LocalProductPlaceholder extends StatelessWidget {
  const _LocalProductPlaceholder({required this.product});

  final ProductRecommendation product;

  IconData _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('storage')) return Icons.inventory_2_outlined;
    if (normalized.contains('organizer')) return Icons.grid_view_outlined;
    if (normalized.contains('furniture')) return Icons.chair_outlined;
    if (normalized.contains('cable')) return Icons.cable_outlined;
    if (normalized.contains('fil')) return Icons.folder_open_outlined;
    if (normalized.contains('hanger')) return Icons.checkroom_outlined;
    return Icons.shopping_bag_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final merchant =
        ProductLinkService.deriveMerchantLabel(product.affiliateLink);
    return Container(
      color: const Color(0xFFEDEFF2),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForCategory(product.category),
                size: 16,
                color: const Color(0xFF8A8A8A),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A8A8A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF646464),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8A8A8A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            I18nService.translate('Image preview unavailable'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8A8A8A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
