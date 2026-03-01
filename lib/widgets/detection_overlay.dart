import 'package:flutter/material.dart';

import '../models/vision_models.dart';
import 'overlay_geometry.dart';

class DetectionOverlay extends StatefulWidget {
  const DetectionOverlay({
    super.key,
    this.image,
    this.imageUrl,
    required this.objects,
    this.fit = BoxFit.cover,
    this.maxDetections = 8,
    this.minConfidence = 0.45,
    this.showBaseImage = true,
  }) : assert(
          image != null || imageUrl != null,
          'Provide either image or imageUrl',
        );

  final ImageProvider? image;
  final String? imageUrl;
  final List<DetectedObject> objects;
  final BoxFit fit;
  final int maxDetections;
  final double minConfidence;
  final bool showBaseImage;

  @override
  State<DetectionOverlay> createState() => _DetectionOverlayState();
}

class _DetectionOverlayState extends State<DetectionOverlay> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;

  ImageProvider get _imageProvider =>
      widget.image ?? NetworkImage(widget.imageUrl!);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant DetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image ||
        oldWidget.imageUrl != widget.imageUrl) {
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImage() {
    final configuration = createLocalImageConfiguration(context);
    final stream = _imageProvider.resolve(configuration);
    if (_stream?.key == stream.key) return;

    _removeImageListener();
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _imageInfo = info);
      },
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _imageInfo = null);
      },
    );
    _stream!.addListener(_listener!);
  }

  void _removeImageListener() {
    final listener = _listener;
    if (_stream != null && listener != null) {
      _stream!.removeListener(listener);
    }
    _listener = null;
    _stream = null;
  }

  @override
  Widget build(BuildContext context) {
    final filteredObjects = widget.objects
        .where((obj) => obj.confidence >= widget.minConfidence)
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final visibleObjects = filteredObjects.take(widget.maxDetections).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayChildren = <Widget>[];
        if (widget.showBaseImage) {
          overlayChildren.add(
            Positioned.fill(
              child: Image(
                image: _imageProvider,
                fit: widget.fit,
              ),
            ),
          );
        }

        final info = _imageInfo;
        if (info == null || visibleObjects.isEmpty) {
          return Stack(children: overlayChildren);
        }

        final geometry = OverlayGeometry.fromSizes(
          inputSize: Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
          outputSize: Size(constraints.maxWidth, constraints.maxHeight),
          fit: widget.fit,
        );

        for (final obj in visibleObjects) {
          final mappedRect = geometry.mapNormalizedBox(obj.box);
          if (mappedRect == null) continue;
          overlayChildren.add(
            Positioned(
              left: mappedRect.left,
              top: mappedRect.top,
              width: mappedRect.width,
              height: mappedRect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF2F80ED),
                      width: 1.4,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0x332F80ED),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F80ED),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${obj.name} ${(obj.confidence * 100).toStringAsFixed(0)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(children: overlayChildren);
      },
    );
  }
}
