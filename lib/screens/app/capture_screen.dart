import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_firebase.dart';
import '../../services/user_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_queue_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/error_recovery_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/registry.dart';
import '../../models/vision_models.dart';
import '../results/results_screen.dart';
import 'processing_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _loading = false;
  XFile? _image;
  final ImageCompressionService _compressionService = ImageCompressionService();

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Scan'),
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to continue.'))
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
                final planName = ((userData['plan'] as String?) ?? '')
                    .toLowerCase()
                    .trim();
                final creditsTotal =
                    (userData['creditsTotal'] as num?)?.toInt();
                final hasUnlimitedCredits =
                    (planName == 'pro' &&
                        (creditsTotal == null || creditsTotal <= 0)) ||
                    credits < 0;
                final hasCredits = hasUnlimitedCredits || credits > 0;

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: _image == null
                            ? const Text('Uploaded File Image Placeholder')
                            : Image.file(File(_image!.path)),
                      ),
                    ),
                    if (!hasCredits)
                      Container(
                        color: Colors.red.withAlpha(26),
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          'You are out of scan credits. Please upgrade your plan to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _loading ? null : _showImageSourceDialog,
                              child: const Text('Upload/Take Photo'),
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
                                  : const Text('Analyze'),
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
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );
    if (source != null) {
      _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Use higher quality from picker, we'll compress intelligently later
    final img = await ImagePicker()
        .pickImage(source: source, imageQuality: 95, maxWidth: 4000);
    if (img != null) {
      setState(() => _image = img);
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
        scaffold.showSnackBar(
            const SnackBar(content: Text('You have no scan credits left.')));
        return;
      }
      final reserved = await UserService.consumeCredit(uid);
      if (!reserved) {
        scaffold.showSnackBar(
            const SnackBar(content: Text('Unable to reserve a scan credit.')));
        return;
      }
      creditReserved = true;
      final img = _image!;
      
      // Show compression progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Optimizing image quality...'),
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
                final fileName = img.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
                final path =
                    'uploads/$uid/${now.toIso8601String()}-$fileName';
                
                // Check connectivity before proceeding
                final isConnected = await connectivityService.checkConnectivity();
                
                VisionAnalysis? analysis;
                String? organizedUrl;
                String? finalImageUrl;
                
                if (!isConnected) {
                  // Offline mode: try to get from cache using a local identifier
                  // For offline, we use a local file path as identifier
                  final localId = 'local_${now.millisecondsSinceEpoch}';
                  final cached = await OfflineCacheService.getCachedAnalysis(localId);
                  
                  if (cached != null && cached.isValid) {
                    analysis = cached.analysis;
                    organizedUrl = cached.organizedImageUrl ?? localId;
                    finalImageUrl = localId;
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Using cached analysis (offline mode)'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    throw Exception('No internet connection and no cached analysis available');
                  }
                } else {
                  // Online mode: upload and analyze
                  final uploadUrl = await Registry.storage.uploadBytes(
                      path: path, data: bytes, contentType: 'image/jpeg');
                  finalImageUrl = uploadUrl;
                  
                  // Attempt analysis with error recovery
                  try {
                    final result = await Registry.vision.analyzeImageUrl(uploadUrl);
                    analysis = result;
                    
                    // Cache the analysis for offline use
                    await OfflineCacheService.cacheAnalysis(
                      imageUrl: uploadUrl,
                      analysis: result,
                    );
                  } catch (e) {
                    // Try error recovery
                    final recovered = await ErrorRecoveryService.attemptRecovery(
                      error: e,
                      retryAction: () async {
                        final result = await Registry.vision.analyzeImageUrl(uploadUrl);
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
                          analysis: const VisionAnalysis(objects: [], labels: []),
                        );
                        throw Exception('Analysis queued for offline sync');
                      }
                      rethrow;
                    }
                  }
                  
                  // Ensure analysis is set
                  final resolvedAnalysis = analysis;
                  if (resolvedAnalysis == null) {
                    throw Exception('Analysis failed');
                  }
                  
                  // Generate organized image with fallback
                  organizedUrl = uploadUrl;
                  try {
                    organizedUrl = await Registry.replicate
                        .generateOrganizedImage(imageUrl: uploadUrl);
                  } catch (replicateError) {
                    if (context.mounted) {
                      debugPrint('Replicate generation failed (using fallback): $replicateError');
                    }
                  }
                  
                  // Save to Firestore (or queue if offline)
                  try {
                    await Registry.analysis.create(
                      uid: uid,
                      title: 'Scan from ${now.toLocal()}',
                      imageUrl: uploadUrl,
                      organizedImageUrl: organizedUrl ?? uploadUrl,
                      analysis: resolvedAnalysis,
                    );
                  } catch (e) {
                    // If save fails, queue for offline sync
                    final stillOffline = !await connectivityService.checkConnectivity();
                    if (stillOffline) {
                      await OfflineQueueService.queueAnalysis(
                        imageUrl: uploadUrl,
                        analysis: resolvedAnalysis,
                        organizedImageUrl: organizedUrl ?? uploadUrl,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analysis saved locally. Will sync when online.'),
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
                    final errorMessage = ErrorRecoveryService.getRecoveryMessage(error);
                    final isRecoverable = ErrorRecoveryService.isRecoverable(error);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        duration: const Duration(seconds: 5),
                        action: isRecoverable
                            ? SnackBarAction(
                                label: 'Retry',
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
                  label: 'Retry',
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
