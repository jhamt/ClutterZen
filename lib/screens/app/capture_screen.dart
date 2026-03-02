import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_firebase.dart';
import '../../services/user_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_queue_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/error_recovery_service.dart';
import '../../services/i18n_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/registry.dart';
import '../../models/vision_models.dart';
import '../results/results_screen.dart';
import 'processing_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.initialSource,
    this.autoPickOnOpen = false,
  });

  final ImageSource? initialSource;
  final bool autoPickOnOpen;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _loading = false;
  XFile? _image;
  final ImageCompressionService _compressionService = ImageCompressionService();
  bool _autoPickStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPickOnOpen && widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoPickStarted) return;
        _autoPickStarted = true;
        _pickImage(widget.initialSource!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18nService.translate('new_scan')),
      ),
      body: uid == null
          ? Center(
              child: Text(I18nService.translate("Please sign in to continue.")))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppFirebase.firestore
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userData =
                    snapshot.data?.data() ?? const <String, dynamic>{};
                final credits = (userData['scanCredits'] as num?)?.toInt() ?? 0;
                final planName =
                    ((userData['plan'] as String?) ?? '').toLowerCase().trim();
                final creditsTotal =
                    (userData['creditsTotal'] as num?)?.toInt();
                final hasUnlimitedCredits = (planName == 'pro' &&
                        (creditsTotal == null || creditsTotal <= 0)) ||
                    credits < 0;
                final hasCredits = hasUnlimitedCredits || credits > 0;

                return Column(
                  children: [
                    Expanded(
                      child: _image == null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF2F7),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 36,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      I18nService.translate(
                                          'no_image_selected_title'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      I18nService.translate(
                                          'no_image_selected_subtitle'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF667085),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_image!.path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                    ),
                    if (!hasCredits)
                      Container(
                        color: Colors.red.withAlpha(26),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          I18nService.translate(
                              "You are out of scan credits. Please upgrade your plan to continue."),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _loading ? null : _showImageSourceDialog,
                              child: Text(
                                I18nService.translate('upload_take_photo'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _image == null || _loading || !hasCredits
                                      ? null
                                      : () => _analyze(
                                            uid,
                                            credits,
                                            hasUnlimitedCredits:
                                                hasUnlimitedCredits,
                                          ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(I18nService.translate('analyze')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  I18nService.translate('pick_image_source'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(I18nService.translate('camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(I18nService.translate('gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Use higher quality from picker, then compress intelligently later.
      final img = await ImagePicker()
          .pickImage(source: source, imageQuality: 95, maxWidth: 4000);
      if (img != null && mounted) {
        setState(() => _image = img);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${I18nService.translate("Unable to pick image")}: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _buildObjectDetectionsPayload(
    VisionAnalysis analysis,
  ) {
    return analysis.objects
        .take(60)
        .map(
          (obj) => {
            'name': obj.name,
            'confidence': obj.confidence,
            'box': {
              'left': obj.box.left,
              'top': obj.box.top,
              'width': obj.box.width,
              'height': obj.box.height,
            },
          },
        )
        .toList(growable: false);
  }

  String _fallbackScanTitle(VisionAnalysis analysis) {
    final names = analysis.objects.map((o) => o.name.toLowerCase()).toList();
    final labels = analysis.labels.map((l) => l.toLowerCase()).toList();
    bool hasAny(List<String> tokens) {
      return names.any((item) => tokens.any(item.contains)) ||
          labels.any((item) => tokens.any(item.contains));
    }

    if (hasAny(['desk', 'workspace', 'laptop', 'monitor'])) {
      return 'Desk Reset Plan';
    }
    if (hasAny(['kitchen', 'plate', 'utensil', 'pan', 'counter'])) {
      return 'Kitchen Reset Plan';
    }
    if (hasAny(['closet', 'wardrobe', 'clothing', 'hanger', 'shoe'])) {
      return 'Closet Reset Plan';
    }
    if (hasAny(['garage', 'tool', 'storage'])) {
      return 'Garage Reset Plan';
    }
    if (hasAny(['bathroom', 'sink', 'toilet', 'shower'])) {
      return 'Bathroom Reset Plan';
    }

    final primary = analysis.objects.isNotEmpty
        ? analysis.objects.first.name
        : (analysis.labels.isNotEmpty ? analysis.labels.first : 'Space');
    final normalized = primary
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    return normalized.isEmpty ? 'Space Reset Plan' : '$normalized Reset Plan';
  }

  Future<String> _resolveScanTitle({
    required VisionAnalysis analysis,
    required String imageUrl,
    required Uint8List imageBytes,
  }) async {
    final fallback = _fallbackScanTitle(analysis);
    try {
      final title = await Registry.gemini.generateScanTitle(
        detectedObjects:
            analysis.objects.map((entry) => entry.name).toList(growable: false),
        labels: analysis.labels,
        objectDetections: _buildObjectDetectionsPayload(analysis),
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        localeCode: I18nService.currentLocale.languageCode,
      );
      final trimmed = title.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    } catch (error) {
      debugPrint('Gemini scan title failed (using fallback): $error');
      return fallback;
    }
  }

  Future<void> _analyze(
    String uid,
    int availableCredits, {
    required bool hasUnlimitedCredits,
  }) async {
    if (_image == null) return;
    setState(() => _loading = true);
    final scaffold = ScaffoldMessenger.of(context);
    bool creditReserved = false;
    try {
      if (!hasUnlimitedCredits && availableCredits <= 0) {
        scaffold.showSnackBar(SnackBar(
            content:
                Text(I18nService.translate("You have no scan credits left."))));
        return;
      }
      final reserved = await UserService.consumeCredit(uid);
      if (!reserved) {
        scaffold.showSnackBar(SnackBar(
            content: Text(
                I18nService.translate("Unable to reserve a scan credit."))));
        return;
      }
      creditReserved = true;
      final img = _image!;

      // Show compression progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18nService.translate("Optimizing image quality...")),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Compress image intelligently while preserving quality
      final compressionResult = await _compressionService.compressImageFile(
        filePath: img.path,
        targetMaxDimension: ImageCompressionService.maxDimensionForAnalysis,
        minQuality: ImageCompressionService.mediumQuality,
        maxFileSize: ImageCompressionService.maxFileSizeForUpload,
      );

      final bytes = compressionResult.bytes;
      final originalSize = compressionResult.originalSize;
      final compressedSize = compressionResult.compressedSize;

      // Log compression stats (can be removed in production)
      if (mounted) {
        debugPrint('Image compression: '
            '${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB -> '
            '${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB '
            '(${compressionResult.sizeReductionPercent.toStringAsFixed(1)}% reduction)');
      }

      if (!mounted) {
        await UserService.refundCredit(uid);
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            background: MemoryImage(bytes),
            onReady: (context) async {
              try {
                final now = DateTime.now();
                // Use .jpg extension for compressed images
                final fileName =
                    img.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
                final path = 'uploads/$uid/${now.toIso8601String()}-$fileName';

                // Check connectivity before proceeding
                final isConnected =
                    await connectivityService.checkConnectivity();

                VisionAnalysis? analysis;
                String? organizedUrl;
                String? finalImageUrl;
                String? analysisDocId;

                if (!isConnected) {
                  // Offline mode: try to get from cache using a local identifier
                  // For offline, we use a local file path as identifier
                  final localId = 'local_${now.millisecondsSinceEpoch}';
                  final cached =
                      await OfflineCacheService.getCachedAnalysis(localId);

                  if (cached != null && cached.isValid) {
                    analysis = cached.analysis;
                    organizedUrl = cached.organizedImageUrl ?? localId;
                    finalImageUrl = localId;

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(I18nService.translate(
                              "Using cached analysis (offline mode)")),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    throw Exception(I18nService.translate(
                        "No internet connection and no cached analysis available"));
                  }
                } else {
                  // Online mode: upload and analyze
                  final uploadUrl = await Registry.storage.uploadBytes(
                      path: path, data: bytes, contentType: 'image/jpeg');
                  finalImageUrl = uploadUrl;

                  // Attempt analysis with error recovery
                  try {
                    final result =
                        await Registry.vision.analyzeImageUrl(uploadUrl);
                    analysis = result;

                    // Cache the analysis for offline use
                    await OfflineCacheService.cacheAnalysis(
                      imageUrl: uploadUrl,
                      analysis: result,
                    );
                  } catch (e) {
                    // Try error recovery
                    final recovered =
                        await ErrorRecoveryService.attemptRecovery(
                      error: e,
                      retryAction: () async {
                        final result =
                            await Registry.vision.analyzeImageUrl(uploadUrl);
                        analysis = result;
                        await OfflineCacheService.cacheAnalysis(
                          imageUrl: uploadUrl,
                          analysis: result,
                        );
                      },
                    );

                    if (!recovered) {
                      // If offline, queue for later
                      if (!isConnected) {
                        await OfflineQueueService.queueAnalysis(
                          imageUrl: uploadUrl,
                          analysis:
                              const VisionAnalysis(objects: [], labels: []),
                        );
                        throw Exception(I18nService.translate(
                            "Analysis queued for offline sync"));
                      }
                      rethrow;
                    }
                  }

                  // Ensure analysis is set
                  final resolvedAnalysis = analysis;
                  if (resolvedAnalysis == null) {
                    throw Exception(I18nService.translate("Analysis failed"));
                  }

                  // Generate organized image with fallback
                  organizedUrl = uploadUrl;
                  try {
                    organizedUrl = await Registry.replicate
                        .generateOrganizedImage(imageUrl: uploadUrl);
                  } catch (replicateError) {
                    if (context.mounted) {
                      debugPrint(
                          'Replicate generation failed (using fallback): $replicateError');
                    }
                  }

                  // Save to Firestore (or queue if offline)
                  try {
                    final scanTitle = await _resolveScanTitle(
                      analysis: resolvedAnalysis,
                      imageUrl: uploadUrl,
                      imageBytes: bytes,
                    );
                    analysisDocId = await Registry.analysis.createAndReturnId(
                      uid: uid,
                      title: scanTitle,
                      imageUrl: uploadUrl,
                      organizedImageUrl: organizedUrl ?? uploadUrl,
                      analysis: resolvedAnalysis,
                    );
                  } catch (e) {
                    // If save fails, queue for offline sync
                    final stillOffline =
                        !await connectivityService.checkConnectivity();
                    if (stillOffline) {
                      await OfflineQueueService.queueAnalysis(
                        imageUrl: uploadUrl,
                        analysis: resolvedAnalysis,
                        organizedImageUrl: organizedUrl ?? uploadUrl,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(I18nService.translate(
                                "Analysis saved locally. Will sync when online.")),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } else {
                      rethrow;
                    }
                  }
                }

                // Navigate to results if we have valid data
                if (context.mounted) {
                  switch ((analysis, finalImageUrl)) {
                    case (VisionAnalysis navAnalysis, final String imageUrl):
                      final imageProvider = imageUrl.startsWith('http')
                          ? NetworkImage(imageUrl) as ImageProvider
                          : MemoryImage(bytes) as ImageProvider;

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ResultsScreen(
                            image: imageProvider,
                            analysis: navAnalysis,
                            organizedUrl: organizedUrl ?? imageUrl,
                            analysisDocId: analysisDocId,
                            organizedRegensUsed: 0,
                            sourceImageUrl:
                                imageUrl.startsWith('http') ? imageUrl : null,
                            sourceImageBytes: bytes,
                          ),
                        ),
                      );
                      break;
                    default:
                      break;
                  }
                }
              } catch (error) {
                await UserService.refundCredit(uid);
                if (!context.mounted) return;
                Navigator.of(context).pop();

                // Use error recovery service for user-friendly messages
                final errorMessage =
                    ErrorRecoveryService.getRecoveryMessage(error);
                final isRecoverable = ErrorRecoveryService.isRecoverable(error);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    duration: const Duration(seconds: 5),
                    action: isRecoverable
                        ? SnackBarAction(
                            label: I18nService.translate("Retry"),
                            onPressed: () => _analyze(
                              uid,
                              availableCredits,
                              hasUnlimitedCredits: hasUnlimitedCredits,
                            ),
                          )
                        : null,
                  ),
                );
              }
            },
          ),
        ),
      );
      creditReserved = false;
    } catch (e) {
      if (creditReserved) {
        await UserService.refundCredit(uid);
      }

      // Use error recovery service for user-friendly messages
      final errorMessage = ErrorRecoveryService.getRecoveryMessage(e);
      final isRecoverable = ErrorRecoveryService.isRecoverable(e);

      scaffold.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: isRecoverable
              ? SnackBarAction(
                  label: I18nService.translate("Retry"),
                  onPressed: () => _analyze(
                    uid,
                    availableCredits,
                    hasUnlimitedCredits: hasUnlimitedCredits,
                  ),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
