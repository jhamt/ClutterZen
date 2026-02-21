import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../results/results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          SizedBox(height: 8),
          _TopBar(),
          SizedBox(height: 12),
          _GreetingRow(),
          SizedBox(height: 12),
          _CenterLogo(),
          SizedBox(height: 12),
          _TitleText(),
          SizedBox(height: 8),
          _PrimaryActions(),
          SizedBox(height: 16),
          _SectionHeader('Recent Categories'),
          SizedBox(height: 8),
          _RecentCategories(),
          SizedBox(height: 16),
          _SectionHeader('Recent Scans'),
          SizedBox(height: 8),
          _RecentScans(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: IconButton(
            onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        const Spacer(),
        _CreditsIndicator(uid: uid),
      ],
    );
  }
}

class _CreditsIndicator extends StatelessWidget {
  const _CreditsIndicator({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const _CreditsChip(text: '0');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppFirebase.firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final credits = (data['scanCredits'] as num?)?.toInt();
        final planName = ((data['plan'] as String?) ?? '').toLowerCase().trim();
        final creditsTotal = (data['creditsTotal'] as num?)?.toInt();
        final unlimited = (planName == 'pro' &&
                (creditsTotal == null || creditsTotal <= 0)) ||
            (credits ?? 0) < 0;
        final text = unlimited ? 'INF' : (credits ?? 0).toString();
        return _CreditsChip(text: text);
      },
    );
  }
}

class _CreditsChip extends StatelessWidget {
  const _CreditsChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined,
              size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _DisplayName(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
      ],
    );
  }
}

class _DisplayName extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AppFirebase.auth.authStateChanges(),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? 'there';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _CenterLogo extends StatelessWidget {
  const _CenterLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF545454)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(36),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/clutterzen-logo-color.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Text(
            'Declutter Anything',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Capture a room and get instant AI organization insights.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF667085),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ShadowButton(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/photo-upload'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111111),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take Photo'),
          ),
        ),
        const SizedBox(height: 12),
        _ShadowButton(
          dark: true,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/photo-upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Upload from Gallery'),
          ),
        ),
      ],
    );
  }
}

class _ShadowButton extends StatelessWidget {
  const _ShadowButton({required this.child, this.dark = false});
  final Widget child;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                (dark ? Colors.black : Colors.black).withAlpha(dark ? 92 : 24),
            blurRadius: dark ? 14 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
}

class _RecentCategories extends StatelessWidget {
  const _RecentCategories();
  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 170, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs;
        // Derive categories list from analyses' categories fields
        final Map<String, String> catToImage = {};
        for (final d in docs) {
          final img = d.data()['imageUrl'] as String?;
          final cats = (d.data()['categories'] as List?)?.cast<String>() ??
              const <String>[];
          for (final c in cats) {
            catToImage.putIfAbsent(c, () => img ?? '');
          }
          if (catToImage.length >= 10) {
            break;
          }
        }
        final items = catToImage.entries.take(10).toList();
        return SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final label = items[i].key;
              final img = items[i].value;
              return Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16)),
                        child: img.isNotEmpty
                            ? Image.network(img, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFF2F4F7),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum _ScanViewMode { list, grid2, grid3 }

class _RecentScans extends StatefulWidget {
  const _RecentScans();

  @override
  State<_RecentScans> createState() => _RecentScansState();
}

class _RecentScansState extends State<_RecentScans> {
  final TextEditingController _searchController = TextEditingController();
  _ScanViewMode _viewMode = _ScanViewMode.list;
  String? _selectedCategory;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _extraDocs = [];
  bool _loadingMore = false;
  bool _allLoaded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPagination() {
    _extraDocs.clear();
    _allLoaded = false;
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(10);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final seenIds = docs.map((d) => d.id).toSet();
        final combinedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...docs
        ];
        for (final doc in _extraDocs) {
          if (seenIds.add(doc.id)) {
            combinedDocs.add(doc);
          }
        }
        final categories = combinedDocs
            .map((d) => (d.data()['primaryCategory'] as String?)?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        final queryText = _searchController.text.trim().toLowerCase();
        final filteredDocs = combinedDocs.where((d) {
          final data = d.data();
          final title = (data['title'] as String?)?.toLowerCase() ?? '';
          final category =
              (data['primaryCategory'] as String?)?.toLowerCase() ?? '';
          final score = (data['clutterScore'] as num?)?.toString() ?? '';

          final matchesSearch = queryText.isEmpty ||
              title.contains(queryText) ||
              category.contains(queryText) ||
              score.contains(queryText);
          final matchesCategory = _selectedCategory == null ||
              (_selectedCategory != null &&
                  (data['primaryCategory'] as String?) == _selectedCategory);

          return matchesSearch && matchesCategory;
        }).toList();

        final lastDoc = combinedDocs.isNotEmpty ? combinedDocs.last : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {
                _resetPagination();
              }),
              decoration: InputDecoration(
                hintText: 'Search scans...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _resetPagination();
                          });
                        },
                      ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ToggleButtons(
                  isSelected: [
                    _viewMode == _ScanViewMode.list,
                    _viewMode == _ScanViewMode.grid2,
                    _viewMode == _ScanViewMode.grid3,
                  ],
                  onPressed: (index) =>
                      setState(() => _viewMode = _ScanViewMode.values[index]),
                  borderRadius: BorderRadius.circular(12),
                  constraints:
                      const BoxConstraints(minHeight: 40, minWidth: 48),
                  children: const [
                    Icon(Icons.view_list),
                    Icon(Icons.grid_view),
                    Icon(Icons.grid_3x3_outlined),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: categories.isEmpty
                      ? null
                      : () => _showFilterSheet(categories),
                  icon: const Icon(Icons.tune),
                  label: Text(
                    _selectedCategory == null
                        ? 'Filter'
                        : 'Filter ($_selectedCategory)',
                  ),
                ),
              ],
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(_selectedCategory!),
                  onDeleted: () => setState(() {
                    _selectedCategory = null;
                    _resetPagination();
                  }),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (filteredDocs.isEmpty)
              Center(
                child: Text(
                  'No scans found. Try a different search or filter.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
            else
              _buildScansView(context, filteredDocs),
            const SizedBox(height: 12),
            _buildLoadMoreButton(context, uid, lastDoc),
          ],
        );
      },
    );
  }

  Widget _buildScansView(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    switch (_viewMode) {
      case _ScanViewMode.list:
        return Column(
          children: [
            for (final doc in docs) ...[
              _buildListCard(context, doc),
              const SizedBox(height: 12),
            ],
          ],
        );
      case _ScanViewMode.grid2:
      case _ScanViewMode.grid3:
        final crossAxisCount = _viewMode == _ScanViewMode.grid2 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) => _buildGridCard(context, docs[index]),
        );
    }
  }

  Widget _buildLoadMoreButton(BuildContext context, String uid,
      QueryDocumentSnapshot<Map<String, dynamic>>? anchor) {
    if (anchor == null) {
      return const SizedBox.shrink();
    }
    if (_allLoaded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'All scans loaded',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _loadingMore ? null : () => _loadMore(uid, anchor),
        child: _loadingMore
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Load more'),
      ),
    );
  }

  Future<void> _loadMore(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> anchor,
  ) async {
    if (_loadingMore || _allLoaded) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final more = await AppFirebase.firestore
          .collection('analyses')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(anchor)
          .limit(10)
          .get();
      if (!mounted) return;
      setState(() {
        _extraDocs.addAll(more.docs);
        _loadingMore = false;
        if (more.docs.isEmpty) {
          _allLoaded = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more scans: $e')),
      );
    }
  }

  Widget _buildListCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final title = (data['title'] as String?) ?? 'Scan';
    final score = (data['clutterScore'] as num?)?.toStringAsFixed(1) ?? '-';

    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isNotEmpty
              ? Image.network(imageUrl,
                  width: 56, height: 56, fit: BoxFit.cover)
              : Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFF2F4F7),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
        ),
        title: Text(title),
        subtitle: Text('Clutter score: $score/10'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(Icons.chevron_right_rounded, size: 18),
        ),
        onTap: () => _openScan(context, doc),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final title = (data['title'] as String?) ?? 'Scan';
    final score = (data['clutterScore'] as num?)?.toStringAsFixed(1) ?? '-';
    final category = (data['primaryCategory'] as String?) ?? 'General';

    return GestureDetector(
      onTap: () => _openScan(context, doc),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      width: double.infinity, fit: BoxFit.cover)
                  : Container(
                      width: double.infinity,
                      color: const Color(0xFFF2F4F7),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(category,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.insights_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('Score $score/10',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScan(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final url = (data['imageUrl'] as String?) ?? '';
    final organized = data['organizedImageUrl'] as String?;
    final labels =
        (data['labels'] as List?)?.cast<String>() ?? const <String>[];
    final objectsRaw = (data['objects'] as List?) ?? const <dynamic>[];
    final objects = objectsRaw.map((o) {
      final box =
          o is Map<String, dynamic> ? o['box'] as Map<String, dynamic>? : null;
      return DetectedObject(
        name: (o is Map<String, dynamic> ? o['name'] as String? : null) ??
            'object',
        confidence:
            (o is Map<String, dynamic> ? (o['confidence'] as num?) : null)
                    ?.toDouble() ??
                0,
        box: BoundingBoxNormalized(
          left: (box?['left'] as num?)?.toDouble() ?? 0,
          top: (box?['top'] as num?)?.toDouble() ?? 0,
          width: (box?['width'] as num?)?.toDouble() ?? 0,
          height: (box?['height'] as num?)?.toDouble() ?? 0,
        ),
      );
    }).toList();
    final analysis = VisionAnalysis(objects: objects, labels: labels);
    if (url.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
            image: NetworkImage(url),
            analysis: analysis,
            organizedUrl: organized),
      ),
    );
  }

  void _showFilterSheet(List<String> categories) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('All categories'),
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                    _resetPagination();
                  });
                  Navigator.of(context).pop();
                },
              ),
              const Divider(),
              if (categories.isEmpty)
                const ListTile(
                  title: Text('No categories available'),
                )
              else
                for (final category in categories)
                  ListTile(
                    title: Text(category),
                    trailing: _selectedCategory == category
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _resetPagination();
                      });
                      Navigator.of(context).pop();
                    },
                  ),
            ],
          ),
        );
      },
    );
  }
}
