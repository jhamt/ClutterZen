import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../../services/i18n_service.dart';
import 'categories_screen.dart';
import 'capture_screen.dart';
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
        children: [
          const SizedBox(height: 8),
          const _TopBar(),
          const SizedBox(height: 12),
          const _GreetingRow(),
          const SizedBox(height: 8),
          const _CenterLogo(),
          const SizedBox(height: 8),
          const _TitleText(),
          const SizedBox(height: 8),
          const _PrimaryActions(),
          SizedBox(height: 16),
          _SectionHeader(I18nService.translate('recent_categories')),
          const SizedBox(height: 8),
          const _RecentCategories(),
          const SizedBox(height: 16),
          _SectionHeader(I18nService.translate('recent_scans')),
          const SizedBox(height: 8),
          const _RecentScans(),
          const SizedBox(height: 16),
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
        _FramedIconButton(
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
          icon: Icons.menu_rounded,
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
        _FramedIconButton(
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
          icon: Icons.settings_outlined,
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
        final user = snap.data;
        final isSignedIn = user != null;
        final rawName = user?.displayName?.trim() ?? '';
        final emailPrefix = (user?.email ?? '').split('@').first.trim();
        final name = rawName.isNotEmpty
            ? rawName
            : emailPrefix.isNotEmpty
                ? emailPrefix
                : isSignedIn
                    ? I18nService.translate('friend')
                    : I18nService.translate('guest');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSignedIn
                  ? I18nService.translate('welcome_back')
                  : I18nService.translate('welcome_guest'),
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7EC)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
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
            I18nService.translate('declutter_anything'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            I18nService.translate('capture_room_subtitle'),
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

class _FramedIconButton extends StatelessWidget {
  const _FramedIconButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CaptureScreen(
                  initialSource: ImageSource.camera,
                  autoPickOnOpen: true,
                ),
              ),
            ),
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
            label: Text(I18nService.translate('take_photo')),
          ),
        ),
        const SizedBox(height: 12),
        _ShadowButton(
          dark: true,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CaptureScreen(
                  initialSource: ImageSource.gallery,
                  autoPickOnOpen: true,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(I18nService.translate('upload_from_gallery')),
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

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.2 + (2.4 * progress), -0.2),
              end: Alignment(-0.2 + (2.4 * progress), 0.2),
              colors: const [
                Color(0xFFE8EBF0),
                Color(0xFFF5F7FA),
                Color(0xFFE8EBF0),
              ],
              stops: const [0.1, 0.45, 0.9],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
    );
  }
}

class _EmptyDataMessage extends StatelessWidget {
  const _EmptyDataMessage({required this.message});
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
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF667085)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF667085)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveUpdateWarning extends StatelessWidget {
  const _LiveUpdateWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) {
              return _Shimmer(
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFE9EDF2),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          height: 14,
                          width: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EDF2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _EmptyDataMessage(message: message),
      ],
    );
  }
}

class _ScansSkeleton extends StatelessWidget {
  const _ScansSkeleton({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < 3; i++) ...[
          _Shimmer(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EDF2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EDF2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 130,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EDF2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i < 2) const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        _EmptyDataMessage(message: message),
      ],
    );
  }
}

class _RecentCategories extends StatelessWidget {
  const _RecentCategories();
  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      return _EmptyDataMessage(
        message: I18nService.translate('scan_images_to_show_here'),
      );
    }
    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return _CategoriesSkeleton(
            message: I18nService.translate('loading_recent_categories'),
          );
        }
        final docs = snap.data?.docs ?? const [];
        final hasError = snap.hasError;
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
        if (items.isEmpty) {
          return Column(
            children: [
              if (hasError)
                _LiveUpdateWarning(
                  message:
                      I18nService.translate('recent_categories_load_error'),
                ),
              if (hasError) const SizedBox(height: 8),
              _EmptyDataMessage(
                message: I18nService.translate('scan_images_to_show_here'),
              ),
            ],
          );
        }
        return Column(
          children: [
            if (hasError)
              _LiveUpdateWarning(
                message: I18nService.translate('recent_categories_load_error'),
              ),
            if (hasError) const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final label = items[i].key;
                  final displayLabel = _formatCategoryTitle(label);
                  final img = items[i].value;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryDetailScreen(
                            title: displayLabel,
                            categoryKey: label,
                          ),
                        ),
                      );
                    },
                    child: Container(
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16)),
                              child: img.isNotEmpty
                                  ? Image.network(img, fit: BoxFit.cover)
                                  : Container(
                                      width: double.infinity,
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
                            child: Text(displayLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCategoryTitle(String raw) {
    final clean = raw.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return 'Category';
    final words = clean.split(RegExp(r'\s+'));
    return words.where((word) => word.isNotEmpty).map((word) {
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
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
    if (uid == null) {
      return _EmptyDataMessage(
        message: I18nService.translate('scan_images_to_show_here'),
      );
    }
    final query = AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(10);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return _ScansSkeleton(
            message: I18nService.translate('loading_recent_scans'),
          );
        }
        final docs = snap.data?.docs ?? const [];
        final hasError = snap.hasError;
        final seenIds = docs.map((d) => d.id).toSet();
        final combinedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...docs
        ];
        for (final doc in _extraDocs) {
          if (seenIds.add(doc.id)) {
            combinedDocs.add(doc);
          }
        }
        final dedupedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final seenImageKeys = <String>{};
        for (final doc in combinedDocs) {
          final imageUrl = (doc.data()['imageUrl'] as String?)?.trim() ?? '';
          final key = imageUrl.isEmpty ? doc.id : imageUrl;
          if (seenImageKeys.add(key)) {
            dedupedDocs.add(doc);
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
        final filteredDocs = dedupedDocs.where((d) {
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
            if (hasError) ...[
              _LiveUpdateWarning(
                message: I18nService.translate('recent_scans_load_error'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {
                _resetPagination();
              }),
              decoration: InputDecoration(
                hintText: I18nService.translate('search_scans'),
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
                        ? I18nService.translate('filter')
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
              combinedDocs.isEmpty
                  ? _EmptyDataMessage(
                      message:
                          I18nService.translate('scan_images_to_show_here'),
                    )
                  : Center(
                      child: Text(
                        I18nService.translate('no_scans_found'),
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
          I18nService.translate('all_scans_loaded'),
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
            : Text(I18nService.translate('load_more')),
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
        SnackBar(
          content: Text(
            '${I18nService.translate('failed_load_more_scans')} $e',
          ),
        ),
      );
    }
  }

  Widget _buildListCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final title = (data['title'] as String?) ?? I18nService.translate("Scan");
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
        subtitle: Text(
          I18nService.translate("Clutter score: {score}/10",
              params: {'score': score}),
        ),
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
    final title = (data['title'] as String?) ?? I18nService.translate("Scan");
    final score = (data['clutterScore'] as num?)?.toStringAsFixed(1) ?? '-';
    final category = (data['primaryCategory'] as String?) ??
        I18nService.translate("General");

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
                      Text(
                          I18nService.translate("Score {score}/10",
                              params: {'score': score}),
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
    final organizedRegensUsed =
        (data['organizedRegensUsed'] as num?)?.toInt() ?? 0;
    final labels =
        (data['labels'] as List?)?.cast<String>() ?? const <String>[];
    final objectsRaw = (data['objects'] as List?) ?? const <dynamic>[];
    final objects = objectsRaw.map((o) {
      final box =
          o is Map<String, dynamic> ? o['box'] as Map<String, dynamic>? : null;
      return DetectedObject(
        name: (o is Map<String, dynamic> ? o['name'] as String? : null) ??
            I18nService.translate("object"),
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
            organizedUrl: organized,
            analysisDocId: doc.id,
            organizedRegensUsed: organizedRegensUsed),
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
                title: Text(I18nService.translate('all_categories')),
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
                ListTile(
                  title: Text(I18nService.translate('no_categories_available')),
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
