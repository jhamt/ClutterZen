import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../../widgets/detection_overlay.dart';
import '../../widgets/organization_zones_overlay.dart';
import 'components/before_after_slider.dart';
import 'components/diy_tab.dart';
import 'components/shop_tab.dart';
import 'components/professional_tab.dart';
import '../../services/analysis_repository.dart';
import '../../backend/registry.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen(
      {super.key,
      required this.image,
      required this.analysis,
      this.organizedUrl});

  final ImageProvider image;
  final VisionAnalysis analysis;
  final String? organizedUrl;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _showDetections = true;
  bool _showZones = false;
  String? _replicateAfterUrl;
  String? _savedDocId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _replicateAfterUrl =
        (widget.organizedUrl != null && widget.organizedUrl!.isNotEmpty)
            ? widget.organizedUrl
            : null;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clutter = _computeClutterScore(
        widget.analysis.objects.length, widget.analysis.labels);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareResults,
          ),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: () => _saveAnalysis()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image + overlay toggle
          Container(
            height: 280,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _showZones
                        ? OrganizationZonesOverlay(
                            analysis: widget.analysis,
                            child:
                                Image(image: widget.image, fit: BoxFit.contain))
                        : (_showDetections
                            ? DetectionOverlay(
                                image: widget.image,
                                objects: widget.analysis.objects)
                            : Image(image: widget.image, fit: BoxFit.contain)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Detections'),
                        Switch(
                            value: _showDetections,
                            onChanged: (v) =>
                                setState(() => _showDetections = v)),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Zones'),
                        Switch(
                            value: _showZones,
                            onChanged: (v) => setState(() => _showZones = v)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Analysis summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _StatTile(
                              label: 'Clutter Score',
                              value: '${clutter.toStringAsFixed(1)}/10',
                              bar: clutter / 10)),
                      Expanded(
                          child: _StatTile(
                              label: 'Items Detected',
                              value: '${widget.analysis.objects.length}')),
                      Expanded(
                          child: _StatTile(
                              label: 'Top Label',
                              value: widget.analysis.labels.isNotEmpty
                                  ? widget.analysis.labels.first
                                  : '—')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: widget.analysis.labels
                        .take(12)
                        .map((l) => Chip(label: Text(l)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Before/After section
          if (widget.image is NetworkImage && _replicateAfterUrl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('Before and After'),
                const SizedBox(height: 8),
                BeforeAfterSlider(
                    before: widget.image,
                    after: NetworkImage(_replicateAfterUrl!)),
                const SizedBox(height: 8),
              ],
            ),
          // Tabs
          Container(
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(text: 'DIY Solution'),
                Tab(text: 'Shop Smart'),
                Tab(text: 'Professional')
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tab,
              children: [
                DIYTab(analysis: widget.analysis),
                ShopTab(analysis: widget.analysis),
                ProfessionalTab(analysis: widget.analysis),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Actions
          _ReplicateAction(
            image: widget.image,
            initialDocId: _savedDocId,
            onAfter: (url) => setState(() => _replicateAfterUrl = url),
          ),
          const SizedBox(height: 8),
          _SaveButton(
            image: widget.image,
            analysis: widget.analysis,
            organizedUrl: _replicateAfterUrl,
            onSaved: (id) => setState(() => _savedDocId = id),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
            child: const Text('Try Another Photo'),
          ),
        ],
      ),
    );
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

  Future<void> _saveAnalysis() async {
    if (widget.image is! NetworkImage) {
      return;
    }
    final url = (widget.image as NetworkImage).url;
    final repo = AnalysisRepository(AppFirebase.firestore, AppFirebase.auth);
    final id = await repo.saveAnalysisAndReturnId(
      imageUrl: url,
      analysis: widget.analysis,
      organizedImageUrl: _replicateAfterUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() => _savedDocId = id);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved analysis')));
  }

  Future<void> _shareResults() async {
    final buffer = StringBuffer('Check out my decluttering results!');
    if (widget.analysis.labels.isNotEmpty) {
      buffer.write(' Top label: ${widget.analysis.labels.first}.');
    }
    if (_replicateAfterUrl != null && _replicateAfterUrl!.isNotEmpty) {
      buffer.write(' Organized preview: $_replicateAfterUrl');
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim()),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.bar});
  final String label;
  final String value;
  final double? bar;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600])),
        if (bar != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(value: bar, minHeight: 6)),
      ],
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton(
      {required this.image,
      required this.analysis,
      this.organizedUrl,
      this.onSaved});

  final ImageProvider image;
  final VisionAnalysis analysis;
  final String? organizedUrl;
  final void Function(String docId)? onSaved;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _saving = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_msg!),
          ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: _saving
              ? const Text('Saving...')
              : const Text('Save analysis to Firestore'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      if (widget.image is! NetworkImage) {
        setState(() {
          _msg = 'Upload the image to storage and analyze via URL to save.';
        });
        return;
      }
      final url = (widget.image as NetworkImage).url;
      final repo = AnalysisRepository(AppFirebase.firestore, AppFirebase.auth);
      final id = await repo.saveAnalysisAndReturnId(
          imageUrl: url,
          analysis: widget.analysis,
          organizedImageUrl: widget.organizedUrl);
      widget.onSaved?.call(id);
      setState(() {
        _msg = 'Saved.';
      });
    } catch (e) {
      setState(() {
        _msg = 'Failed: $e';
      });
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }
}

class _ReplicateAction extends StatefulWidget {
  const _ReplicateAction(
      {required this.image, this.onAfter, this.initialDocId});

  final ImageProvider image;
  final void Function(String url)? onAfter;
  final String? initialDocId;

  @override
  State<_ReplicateAction> createState() => _ReplicateActionState();
}

class _ReplicateActionState extends State<_ReplicateAction> {
  bool _loading = false;
  String? _afterUrl;
  String? _error;
  String? _analysisDocId;

  @override
  void initState() {
    super.initState();
    _analysisDocId = widget.initialDocId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_afterUrl != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Organized preview:'),
              const SizedBox(height: 8),
              SizedBox(
                  height: 200,
                  child: Image.network(_afterUrl!, fit: BoxFit.cover)),
            ],
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Generating organized preview...')),
              ],
            ),
          ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_outlined),
          label: _loading
              ? const Text('Generating...')
              : const Text('Generate Organized Image'),
        ),
      ],
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Requires an accessible URL; if using local image, upload to storage first and pass URL.
      // For this demo, we only support NetworkImage here.
      if (widget.image is! NetworkImage) {
        setState(() => _error = 'Replicate demo needs a public image URL.');
        return;
      }
      final url = (widget.image as NetworkImage).url;
      final after = await Registry.replicate.generateOrganizedImage(
        imageUrl: url,
      );

      setState(() {
        _afterUrl = after;
      });

      widget.onAfter?.call(after);
      // Optionally save/update analysis with organized image URL if a prior save exists
      try {
        final repo =
            AnalysisRepository(AppFirebase.firestore, AppFirebase.auth);
        if (_analysisDocId == null) {
          // Try to find the latest analysis for this image and user, then update
          final uid = AppFirebase.auth.currentUser?.uid;
          if (uid != null) {
            final q = await AppFirebase.firestore
                .collection('analyses')
                .where('uid', isEqualTo: uid)
                .where('imageUrl', isEqualTo: url)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              _analysisDocId = q.docs.first.id;
            }
          }
          if (_analysisDocId == null) {
            // Create a minimal record to attach the organized image
            final analysis = const VisionAnalysis(objects: [], labels: []);
            _analysisDocId = await repo.saveAnalysisAndReturnId(
                imageUrl: url, analysis: analysis, organizedImageUrl: after);
          } else {
            await repo.updateOrganizedImage(_analysisDocId!, after);
          }
        } else {
          await repo.updateOrganizedImage(_analysisDocId!, after);
        }
      } catch (_) {
        // Non-fatal: do not block UI if Firestore write fails
      }
    } catch (e) {
      final errorString = e.toString();
      String errorMessage;

      if (errorString.contains('timeout') || errorString.contains('Timeout')) {
        errorMessage = 'Generation timed out. Using original image.';
      } else if (errorString.contains('network') ||
          errorString.contains('Network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else {
        errorMessage = 'Generation failed: ${e.toString()}';
      }

      setState(() => _error = errorMessage);
    } finally {
      setState(() => _loading = false);
    }
  }
}
