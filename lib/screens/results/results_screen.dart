import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_firebase.dart';
import '../../backend/registry.dart';
import '../../models/recommendation_context.dart';
import '../../models/vision_models.dart';
import '../../services/analysis_repository.dart';
import '../../services/recommendation_context_builder.dart';
import '../../widgets/detection_overlay.dart';
import '../../widgets/organization_zones_overlay.dart';
import 'components/before_after_slider.dart';
import 'components/diy_tab.dart';
import 'components/professional_tab.dart';
import 'components/shop_tab.dart';

import '../../services/i18n_service.dart';

enum _OverlayMode { image, detections, zones }

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.image,
    required this.analysis,
    this.organizedUrl,
    this.analysisDocId,
    this.organizedRegensUsed = 0,
    this.sourceImageUrl,
    this.sourceImageBytes,
  });

  final ImageProvider image;
  final VisionAnalysis analysis;
  final String? organizedUrl;
  final String? analysisDocId;
  final int organizedRegensUsed;
  final String? sourceImageUrl;
  final Uint8List? sourceImageBytes;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxManualRegens = 5;

  late final TabController _tab;
  late final ScrollController _scrollController;
  final Map<int, Widget> _tabViews = <int, Widget>{};
  _OverlayMode _overlayMode = _OverlayMode.detections;
  bool _hasScrolledBody = false;

  String? _replicateAfterUrl;
  String? _analysisDocId;
  int _organizedRegensUsed = 0;
  late final RecommendationContext _recommendationContext;

  bool _isGeneratingAfter = false;
  bool _afterImageLoadFailed = false;
  String? _afterError;
  String? _lastFailedAfterUrl;

  int get _attemptsLeft => math.max(0, _maxManualRegens - _organizedRegensUsed);

  bool get _canRegenerate =>
      !_isGeneratingAfter && _attemptsLeft > 0 && widget.image is NetworkImage;

  @override
  void initState() {
    super.initState();
    _recommendationContext = _buildRecommendationContext();
    _scrollController = ScrollController()..addListener(_onBodyScroll);
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (!mounted) return;
      _ensureTabBuilt(_tab.index);
      setState(() {});
    });
    _ensureTabBuilt(0);
    _replicateAfterUrl = null;
    _analysisDocId = widget.analysisDocId;
    _organizedRegensUsed = widget.organizedRegensUsed < 0
        ? 0
        : widget.organizedRegensUsed.clamp(0, _maxManualRegens);
    _hydrateInitialOrganizedImage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onBodyScroll)
      ..dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clutter = _computeClutterScore(
      widget.analysis.objects.length,
      widget.analysis.labels,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor:
            _hasScrolledBody ? const Color(0xFFEAF4F7) : Colors.white,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(I18nService.translate("Results")),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareResults,
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _buildOverlayModeSelector(context),
          const SizedBox(height: 12),
          _buildHeroImageCard(),
          const SizedBox(height: 14),
          _buildSummaryCard(context, clutter),
          const SizedBox(height: 16),
          _buildBeforeAfterSection(context),
          const SizedBox(height: 16),
          _buildTabs(context),
          const SizedBox(height: 12),
          _buildActiveTabContent(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
            child: Text(I18nService.translate("Try Another Photo")),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayModeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: SegmentedButton<_OverlayMode>(
        showSelectedIcon: false,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF344054);
          }),
        ),
        segments: [
          ButtonSegment<_OverlayMode>(
            value: _OverlayMode.image,
            label: Text(I18nService.translate("Image")),
          ),
          ButtonSegment<_OverlayMode>(
            value: _OverlayMode.detections,
            label: Text(I18nService.translate("Detections")),
          ),
          ButtonSegment<_OverlayMode>(
            value: _OverlayMode.zones,
            label: Text(I18nService.translate("Zones")),
          ),
        ],
        selected: {_overlayMode},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;
          setState(() => _overlayMode = selection.first);
        },
      ),
    );
  }

  Widget _buildHeroImageCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFEFF2F6)),
          child: switch (_overlayMode) {
            _OverlayMode.image => Image(image: widget.image, fit: BoxFit.cover),
            _OverlayMode.detections => DetectionOverlay(
                image: widget.image,
                objects: widget.analysis.objects,
                fit: BoxFit.cover,
                maxDetections: 8,
                minConfidence: 0.45,
                showBaseImage: true,
              ),
            _OverlayMode.zones => OrganizationZonesOverlay(
                image: widget.image,
                objects: widget.analysis.objects,
                fit: BoxFit.cover,
                showBaseImage: true,
              ),
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double clutter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: I18nService.translate("Clutter score"),
                    value: '${clutter.toStringAsFixed(1)}/10',
                    bar: clutter / 10,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: I18nService.translate("Items"),
                    value: '${widget.analysis.objects.length}',
                    isCentered: true,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: I18nService.translate("Top label"),
                    value: widget.analysis.labels.isNotEmpty
                        ? widget.analysis.labels.first
                        : '-',
                  ),
                ),
              ],
            ),
            if (widget.analysis.labels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.analysis.labels
                    .take(12)
                    .map((label) => Chip(label: Text(label)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeAfterSection(BuildContext context) {
    final hasAfterUrl =
        _replicateAfterUrl != null && _replicateAfterUrl!.isNotEmpty;
    final showAfterUnavailableCard = hasAfterUrl && _afterImageLoadFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              I18nService.translate("Before and After"),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: Text(
                '${_attemptsLeft.toString()}/${_maxManualRegens.toString()} ${I18nService.translate("left")}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475467),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hasAfterUrl && !_afterImageLoadFailed)
          SizedBox(
            width: double.infinity,
            child: BeforeAfterSlider(
              before: widget.image,
              after: NetworkImage(_replicateAfterUrl!),
              height: 320,
              onAfterStateChanged: _handleAfterImageStateChanged,
            ),
          )
        else if (showAfterUnavailableCard)
          _buildAfterImageUnavailableCard(context)
        else
          _InlineNotice(
            icon: Icons.image_outlined,
            message: I18nService.translate(
                "No organized image yet. Generate one to see before/after."),
          ),
        if (_afterImageLoadFailed && !hasAfterUrl) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.error_outline,
            message: I18nService.translate(
                "Unable to load organized image. Generate a fresh version."),
            isError: true,
          ),
        ],
        if (_afterError != null && !showAfterUnavailableCard) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.warning_amber_rounded,
            message: _afterError!,
            isError: true,
          ),
        ],
        if (!showAfterUnavailableCard) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canRegenerate ? _generateNewOrganizedImage : null,
              icon: _isGeneratingAfter
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high_outlined),
              label: Text(
                _isGeneratingAfter
                    ? I18nService.translate("Generating...")
                    : _attemptsLeft == 0
                        ? I18nService.translate("Regeneration limit reached")
                        : I18nService.translate("Generate new organized image"),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: Center(
              child: Text(
                widget.image is NetworkImage
                    ? I18nService.translate(
                        "Results save automatically to your history.")
                    : I18nService.translate(
                        "Regeneration is only available for uploaded scans."),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                    ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Row(
        children: [
          _ResultsTabButton(
            label: I18nService.translate("DIY Solution"),
            selected: _tab.index == 0,
            onTap: () => _tab.animateTo(0),
          ),
          _ResultsTabButton(
            label: I18nService.translate("Shop Smart"),
            selected: _tab.index == 1,
            onTap: () => _tab.animateTo(1),
          ),
          _ResultsTabButton(
            label: I18nService.translate("Professional"),
            selected: _tab.index == 2,
            onTap: () => _tab.animateTo(2),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterImageUnavailableCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.broken_image_outlined,
                size: 18,
                color: Color(0xFFB42318),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  I18nService.translate("Organized image unavailable"),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            I18nService.translate(
                "Generate again to fetch a fresh organized image."),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF475467),
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canRegenerate ? _generateNewOrganizedImage : null,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(I18nService.translate("Regenerate organized image")),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_attemptsLeft.toString()}/${_maxManualRegens.toString()} ${I18nService.translate("attempts left")}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667085),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    _ensureTabBuilt(0);
    _ensureTabBuilt(1);
    _ensureTabBuilt(2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (index) {
        final tabView = _tabViews[index];
        if (tabView == null) {
          return const SizedBox.shrink();
        }
        return Offstage(
          offstage: _tab.index != index,
          child: TickerMode(
            enabled: _tab.index == index,
            child: tabView,
          ),
        );
      }),
    );
  }

  void _onBodyScroll() {
    final hasScrolled =
        _scrollController.hasClients && _scrollController.offset > 1.0;
    if (hasScrolled == _hasScrolledBody || !mounted) {
      return;
    }
    setState(() {
      _hasScrolledBody = hasScrolled;
    });
  }

  void _ensureTabBuilt(int index) {
    _tabViews.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return DIYTab(
            analysis: widget.analysis,
            embedded: true,
            recommendationContext: _recommendationContext,
          );
        case 1:
          return ShopTab(
            analysis: widget.analysis,
            embedded: true,
          );
        case 2:
        default:
          return ProfessionalTab(
            analysis: widget.analysis,
            embedded: true,
            recommendationContext: _recommendationContext,
          );
      }
    });
  }

  RecommendationContext _buildRecommendationContext() {
    final clutter10 = _computeClutterScore(
      widget.analysis.objects.length,
      widget.analysis.labels,
    );
    final clutter100 = (clutter10 * 10).clamp(0.0, 100.0);
    final networkImageUrl = widget.image is NetworkImage
        ? (widget.image as NetworkImage).url
        : null;
    final resolvedImageUrl = widget.sourceImageUrl ?? networkImageUrl;

    return RecommendationContextBuilder.build(
      analysis: widget.analysis,
      clutterScore: clutter100,
      localeCode: I18nService.currentLocale.languageCode,
      detailLevel: 'balanced',
      imageUrl: resolvedImageUrl,
      imageBytes: widget.sourceImageBytes,
    );
  }

  Future<void> _generateNewOrganizedImage() async {
    if (widget.image is! NetworkImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(I18nService.translate(
                "Please analyze an uploaded image first."))),
      );
      return;
    }
    if (_attemptsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                I18nService.translate("You reached the regeneration limit."))),
      );
      return;
    }

    final originalUrl = (widget.image as NetworkImage).url;
    final previousAfterUrl = _replicateAfterUrl;

    setState(() {
      _isGeneratingAfter = true;
      _afterError = null;
    });

    try {
      final generatedUrl = await Registry.replicate.generateOrganizedImage(
        imageUrl: originalUrl,
        allowFallback: false,
      );
      final normalizedRaw = generatedUrl.trim();
      if (normalizedRaw.isEmpty) {
        throw Exception(
            I18nService.translate("No organized image was returned."));
      }
      final docId = await _ensureAnalysisDocId(originalUrl);
      final normalizedUrl = await _resolveDisplayImageUrl(normalizedRaw);
      if (_isSameImageReference(normalizedUrl, originalUrl) ||
          (_replicateAfterUrl != null &&
              _isSameImageReference(normalizedUrl, _replicateAfterUrl!))) {
        throw Exception(
            I18nService.translate("Generated image did not change."));
      }
      final loadable = await _prefetchImageUrl(normalizedUrl);
      if (!loadable) {
        throw Exception(
            I18nService.translate("Generated image URL could not be loaded."));
      }
      final nextUsed = _organizedRegensUsed + 1;

      final repo = AnalysisRepository(AppFirebase.firestore, AppFirebase.auth);
      await repo.updateOrganizedImageMetadata(
        docId: docId,
        organizedImageUrl: normalizedUrl,
        organizedRegensUsed: nextUsed,
      );

      if (!mounted) return;
      setState(() {
        _replicateAfterUrl = normalizedUrl;
        _organizedRegensUsed = nextUsed;
        _afterImageLoadFailed = false;
        _afterError = null;
        _lastFailedAfterUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _replicateAfterUrl = previousAfterUrl;
        _afterError = _mapGenerationError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAfter = false);
      }
    }
  }

  Future<String> _ensureAnalysisDocId(String imageUrl) async {
    final existing = _analysisDocId;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      throw Exception(I18nService.translate("Please sign in and try again."));
    }

    final query = await AppFirebase.firestore
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .where('imageUrl', isEqualTo: imageUrl)
        .limit(10)
        .get();

    if (query.docs.isNotEmpty) {
      final sortedDocs = query.docs.toList()
        ..sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
      final doc = sortedDocs.first;
      _analysisDocId = doc.id;
      _organizedRegensUsed =
          (doc.data()['organizedRegensUsed'] as num?)?.toInt() ??
              _organizedRegensUsed;
      return doc.id;
    }

    throw Exception(
        I18nService.translate("Scan record not found. Please analyze again."));
  }

  Future<void> _hydrateInitialOrganizedImage() async {
    try {
      var rawUrl = widget.organizedUrl?.trim();
      if (rawUrl != null && rawUrl.isEmpty) {
        rawUrl = null;
      }

      final docId = _analysisDocId;
      if (docId != null && docId.isNotEmpty) {
        final doc =
            await AppFirebase.firestore.collection('analyses').doc(docId).get();
        final data = doc.data();
        final storedRaw = (data?['organizedImageUrl'] as String?)?.trim();
        if (storedRaw != null && storedRaw.isNotEmpty) {
          rawUrl = storedRaw;
        }
        if (data != null) {
          _organizedRegensUsed =
              (data['organizedRegensUsed'] as num?)?.toInt() ??
                  _organizedRegensUsed;
        }
      }

      if (rawUrl == null || rawUrl.isEmpty) {
        return;
      }

      final resolved = await _resolveDisplayImageUrl(rawUrl);
      final sourceImageUrl = widget.image is NetworkImage
          ? (widget.image as NetworkImage).url
          : '';
      if (sourceImageUrl.isNotEmpty &&
          _isSameImageReference(resolved, sourceImageUrl)) {
        return;
      }
      final loadable = await _prefetchImageUrl(resolved);
      if (!loadable) {
        if (!mounted) return;
        setState(() {
          _replicateAfterUrl = resolved;
          _afterImageLoadFailed = true;
          _afterError = I18nService.translate(
              "Generated image could not be loaded. Please regenerate.");
          _lastFailedAfterUrl = resolved;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _replicateAfterUrl = resolved;
        _afterImageLoadFailed = false;
        _afterError = null;
        _lastFailedAfterUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _afterError = _mapGenerationError(e);
      });
    }
  }

  Future<String> _resolveDisplayImageUrl(String rawUrl) async {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      throw Exception(
          I18nService.translate("No organized image was returned."));
    }

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        return value;
      }
      if (scheme == 'gs') {
        return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
      }
      throw Exception(
          '${I18nService.translate("Unsupported organized image URL scheme")}: $scheme');
    }

    final normalizedPath = value.startsWith('/') ? value.substring(1) : value;
    if (normalizedPath.isEmpty) {
      throw Exception(I18nService.translate("Invalid organized image path."));
    }
    return FirebaseStorage.instance.ref(normalizedPath).getDownloadURL();
  }

  Future<bool> _prefetchImageUrl(
    String imageUrl, {
    int attempts = 3,
    Duration retryDelay = const Duration(milliseconds: 450),
  }) async {
    final parsed = Uri.tryParse(imageUrl.trim());
    if (parsed == null ||
        !(parsed.isScheme('https') || parsed.isScheme('http')) ||
        parsed.host.isEmpty ||
        !mounted) {
      return false;
    }
    final tries = attempts < 1 ? 1 : attempts;
    for (var attempt = 1; attempt <= tries; attempt++) {
      if (!mounted) return false;
      try {
        await precacheImage(NetworkImage(imageUrl), context);
        return true;
      } catch (_) {
        if (attempt >= tries) {
          return false;
        }
        await Future<void>.delayed(retryDelay);
      }
    }
    return false;
  }

  void _handleAfterImageStateChanged(bool failed) {
    if (!mounted) return;
    if (!failed) {
      if (_afterImageLoadFailed || _afterError != null) {
        setState(() {
          _afterImageLoadFailed = false;
          _afterError = null;
          _lastFailedAfterUrl = null;
        });
      }
      return;
    }

    final currentAfterUrl = _replicateAfterUrl;
    if (currentAfterUrl != null && _lastFailedAfterUrl == currentAfterUrl) {
      return;
    }
    setState(() {
      _afterImageLoadFailed = true;
      _afterError = I18nService.translate(
          "Generated image could not be loaded. Please regenerate.");
      _lastFailedAfterUrl = currentAfterUrl;
    });
  }

  bool _isSameImageReference(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left == right) return true;

    final leftUri = Uri.tryParse(left);
    final rightUri = Uri.tryParse(right);
    if (leftUri == null || rightUri == null) {
      return false;
    }
    if ((leftUri.scheme == 'http' || leftUri.scheme == 'https') &&
        (rightUri.scheme == 'http' || rightUri.scheme == 'https')) {
      return leftUri.host == rightUri.host && leftUri.path == rightUri.path;
    }
    return false;
  }

  String _mapGenerationError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('no organized image was returned') ||
        message.contains('no valid output url') ||
        message.contains('empty output url') ||
        message.contains('no response payload')) {
      return I18nService.translate(
          "After-image API returned no response. Please regenerate.");
    }
    if (message.contains('endpoint not found') || message.contains('404')) {
      return I18nService.translate(
          "Organized-image endpoint not found. Check function deployment.");
    }
    if (message.contains('unsupported organized image url scheme') ||
        message.contains('invalid organized image path')) {
      return I18nService.translate(
          "Organized image link is invalid. Generate a fresh version.");
    }
    if (message.contains('network')) {
      return I18nService.translate(
          "Network issue while generating image. Check connection and retry.");
    }
    if (message.contains('timeout')) {
      return I18nService.translate("Generation timed out. Please try again.");
    }
    if (message.contains('not configured')) {
      return I18nService.translate(
          "Image generation is not configured on server yet.");
    }
    if (message.contains('could not be loaded') ||
        message.contains('unusable url')) {
      return I18nService.translate(
          "Generated image could not be loaded. Please regenerate.");
    }
    if (message.contains('did not change')) {
      return I18nService.translate(
          "Generation did not produce a new image. Try again.");
    }
    return I18nService.translate(
        "Unable to generate organized image right now. Please retry.");
  }

  double _computeClutterScore(int objectCount, List<String> labels) {
    double score;
    if (objectCount < 5) {
      score = 2.0;
    } else if (objectCount < 10) {
      score = 3.5;
    } else if (objectCount < 15) {
      score = 5.0;
    } else if (objectCount < 25) {
      score = 6.5;
    } else if (objectCount < 35) {
      score = 8.0;
    } else {
      score = 9.5;
    }

    for (final label in labels) {
      final lower = label.toLowerCase();
      if (lower.contains('messy') ||
          lower.contains('clutter') ||
          lower.contains('disorganized') ||
          lower.contains('pile') ||
          lower.contains('scattered')) {
        score += 1.5;
      }
      if (lower.contains('organized') ||
          lower.contains('tidy') ||
          lower.contains('clean') ||
          lower.contains('minimal') ||
          lower.contains('neat')) {
        score -= 1.5;
      }
    }

    return score.clamp(1.0, 10.0);
  }

  Future<void> _shareResults() async {
    final buffer = StringBuffer(
        I18nService.translate("Check out my decluttering results!"));
    if (widget.analysis.labels.isNotEmpty) {
      buffer.write(
          ' ${I18nService.translate("Top label")}: ${widget.analysis.labels.first}.');
    }
    if (_replicateAfterUrl != null && _replicateAfterUrl!.isNotEmpty) {
      buffer.write(
          ' ${I18nService.translate("Organized preview")}: $_replicateAfterUrl');
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim()),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final background =
        isError ? const Color(0xFFFFF1F1) : const Color(0xFFF8FAFC);
    final border = isError ? const Color(0xFFFEB2B2) : const Color(0xFFD0D5DD);
    final textColor =
        isError ? const Color(0xFFB42318) : const Color(0xFF475467);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.bar,
    this.isCentered = false,
  });

  final String label;
  final String value;
  final double? bar;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final crossAxis =
        isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = isCentered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: crossAxis,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF667085),
              ),
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (bar != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(
              value: bar!.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFDCE4ED),
            ),
          ),
      ],
    );
  }
}

class _ResultsTabButton extends StatelessWidget {
  const _ResultsTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF475467),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
