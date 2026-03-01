import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../../services/i18n_service.dart';
import '../results/results_screen.dart';
import 'capture_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate("Categories"))),
      body: uid == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: _CategoryInfoCard(
                message: 'Sign in to view your scan categories.',
              ),
            )
          : _DynamicCategoriesGrid(uid: uid),
    );
  }
}

class _DynamicCategoriesGrid extends StatelessWidget {
  const _DynamicCategoriesGrid({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(120);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const _CategoriesLoadingGrid();
        }

        final docs = snapshot.data?.docs ?? const [];
        final categories = _buildDynamicCategories(docs);
        final hasError = snapshot.hasError;

        if (categories.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasError) ...[
                const _CategoriesWarningBanner(
                  message:
                      'Live updates failed. Showing available local results.',
                ),
                const SizedBox(height: 10),
              ],
              const _CategoryInfoCard(
                message: 'Scan images to build your categories automatically.',
              ),
            ],
          );
        }

        return Column(
          children: [
            if (hasError)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _CategoriesWarningBanner(
                  message:
                      'Live updates failed. Showing last known categories.',
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.84,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryCard(category: category);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _DynamicCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(
              title: category.title,
              categoryKey: category.key,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: category.imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFFF2F4F7),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF98A2B3),
                      ),
                    )
                  : Image.network(
                      category.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF2F4F7),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.count} scan${category.count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    super.key,
    required this.title,
    this.categoryKey,
  });

  final String title;
  final String? categoryKey;

  @override
  Widget build(BuildContext context) {
    final tips = I18nService.recommendedSteps();
    final normalizedCategory = _normalizeCategory(categoryKey ?? title);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            I18nService.translate('recommended_steps'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final tip in tips) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(tip),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          _CategoryScansSection(
            title: title,
            normalizedCategory: normalizedCategory,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CaptureScreen(
                  initialSource: ImageSource.camera,
                  autoPickOnOpen: true,
                ),
              ),
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(I18nService.translate('capture_this_room')),
          ),
        ],
      ),
    );
  }
}

class _CategoryScansSection extends StatelessWidget {
  const _CategoryScansSection({
    required this.title,
    required this.normalizedCategory,
  });

  final String title;
  final String normalizedCategory;

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      return const _CategoryInfoCard(
        message: 'Sign in to view scans in this category.',
      );
    }

    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(120);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scans in $title',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? const [];
            final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final seenImages = <String>{};

            for (final doc in docs) {
              final data = doc.data();
              final primary = _normalizeCategory(
                  (data['primaryCategory'] as String?) ?? '');
              final categoriesRaw = data['categories'];
              final categories = categoriesRaw is List
                  ? categoriesRaw
                      .map((entry) => _normalizeCategory(entry.toString()))
                      .where((value) => value.isNotEmpty)
                      .toList()
                  : const <String>[];

              final matches = primary == normalizedCategory ||
                  categories.contains(normalizedCategory);
              if (!matches) continue;

              final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
              final dedupeKey = imageUrl.isEmpty ? doc.id : imageUrl;
              if (seenImages.add(dedupeKey)) {
                filtered.add(doc);
              }
            }

            filtered.sort((a, b) {
              final left = a.data()['createdAt'] as Timestamp?;
              final right = b.data()['createdAt'] as Timestamp?;
              if (left == null && right == null) return 0;
              if (left == null) return 1;
              if (right == null) return -1;
              return right.compareTo(left);
            });

            if (filtered.isEmpty) {
              return const _CategoryInfoCard(
                message: 'No scans found in this category yet.',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length > 12 ? 12 : filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _CategoryScanTile(doc: filtered[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryInfoCard extends StatelessWidget {
  const _CategoryInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF667085),
            ),
      ),
    );
  }
}

class _CategoryScanTile extends StatelessWidget {
  const _CategoryScanTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final title = (data['title'] as String?) ?? 'Scan';
    final score = (data['clutterScore'] as num?)?.toStringAsFixed(1) ?? '-';
    final createdAt = data['createdAt'] as Timestamp?;
    final createdText = createdAt == null
        ? ''
        : '${createdAt.toDate().month}/${createdAt.toDate().day}/${createdAt.toDate().year}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openScan(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFF2F4F7),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (createdText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      createdText,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1F6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$score/10',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScan(BuildContext context) {
    final data = doc.data();
    final url = (data['imageUrl'] as String?) ?? '';
    if (url.isEmpty) return;

    final organized = data['organizedImageUrl'] as String?;
    final organizedRegensUsed =
        (data['organizedRegensUsed'] as num?)?.toInt() ?? 0;
    final labels =
        (data['labels'] as List?)?.cast<String>() ?? const <String>[];
    final objectsRaw = (data['objects'] as List?) ?? const <dynamic>[];
    final objects = objectsRaw.map((entry) {
      final item = entry is Map<String, dynamic> ? entry : <String, dynamic>{};
      final box = item['box'] as Map<String, dynamic>?;
      return DetectedObject(
        name: (item['name'] as String?) ?? 'object',
        confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
        box: BoundingBoxNormalized(
          left: (box?['left'] as num?)?.toDouble() ?? 0,
          top: (box?['top'] as num?)?.toDouble() ?? 0,
          width: (box?['width'] as num?)?.toDouble() ?? 0,
          height: (box?['height'] as num?)?.toDouble() ?? 0,
        ),
      );
    }).toList();
    final analysis = VisionAnalysis(objects: objects, labels: labels);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          image: NetworkImage(url),
          analysis: analysis,
          organizedUrl: organized,
          analysisDocId: doc.id,
          organizedRegensUsed: organizedRegensUsed,
        ),
      ),
    );
  }
}

class _CategoriesLoadingGrid extends StatelessWidget {
  const _CategoriesLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.84,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
      ),
    );
  }
}

class _CategoriesWarningBanner extends StatelessWidget {
  const _CategoriesWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCCB9C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB54708)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A2E0B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicCategory {
  const _DynamicCategory({
    required this.key,
    required this.title,
    required this.imageUrl,
    required this.count,
    this.latestAt,
  });

  final String key;
  final String title;
  final String imageUrl;
  final int count;
  final Timestamp? latestAt;
}

class _DynamicCategoryAccumulator {
  _DynamicCategoryAccumulator({
    required this.key,
    required this.title,
  });

  final String key;
  final String title;
  final Set<String> _seenScanKeys = <String>{};
  String imageUrl = '';
  Timestamp? latestAt;
  int count = 0;

  void registerScan({
    required String docId,
    required String imageUrl,
    required Timestamp? createdAt,
  }) {
    final dedupeKey = imageUrl.isEmpty ? docId : imageUrl;
    if (_seenScanKeys.add(dedupeKey)) {
      count += 1;
    }

    final isNewer = latestAt == null ||
        (createdAt != null && createdAt.compareTo(latestAt!) > 0);
    if (isNewer) {
      latestAt = createdAt;
      if (imageUrl.isNotEmpty) {
        this.imageUrl = imageUrl;
      }
    } else if (this.imageUrl.isEmpty && imageUrl.isNotEmpty) {
      this.imageUrl = imageUrl;
    }
  }

  _DynamicCategory freeze() {
    return _DynamicCategory(
      key: key,
      title: title,
      imageUrl: imageUrl,
      count: count,
      latestAt: latestAt,
    );
  }
}

List<_DynamicCategory> _buildDynamicCategories(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final buckets = <String, _DynamicCategoryAccumulator>{};

  for (final doc in docs) {
    final data = doc.data();
    final imageUrl = ((data['imageUrl'] as String?) ?? '').trim();
    final createdAt = data['createdAt'] as Timestamp?;
    final categoryKeys = <String>{};

    final primary =
        _normalizeCategory((data['primaryCategory'] as String?) ?? '');
    if (primary.isNotEmpty) {
      categoryKeys.add(primary);
    }

    final categoriesRaw = data['categories'];
    if (categoriesRaw is List) {
      for (final item in categoriesRaw) {
        final normalized = _normalizeCategory(item.toString());
        if (normalized.isNotEmpty) {
          categoryKeys.add(normalized);
        }
      }
    }

    for (final categoryKey in categoryKeys) {
      final bucket = buckets.putIfAbsent(
        categoryKey,
        () => _DynamicCategoryAccumulator(
          key: categoryKey,
          title: _formatCategoryTitle(categoryKey),
        ),
      );
      bucket.registerScan(
        docId: doc.id,
        imageUrl: imageUrl,
        createdAt: createdAt,
      );
    }
  }

  final items = buckets.values.map((entry) => entry.freeze()).toList();
  items.sort((left, right) {
    final leftTime = left.latestAt;
    final rightTime = right.latestAt;
    if (leftTime == null && rightTime == null) {
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    }
    if (leftTime == null) return 1;
    if (rightTime == null) return -1;
    final byDate = rightTime.compareTo(leftTime);
    if (byDate != 0) return byDate;
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });
  return items;
}

String _normalizeCategory(String raw) {
  return raw.trim().toLowerCase().replaceAll('_', ' ').replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
}

String _formatCategoryTitle(String raw) {
  final clean = _normalizeCategory(raw);
  if (clean.isEmpty) return 'Category';
  return clean.split(' ').map((word) {
    if (word.isEmpty) return word;
    if (word.length == 1) return word.toUpperCase();
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }).join(' ');
}
