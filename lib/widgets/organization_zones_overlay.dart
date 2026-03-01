import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vision_models.dart';
import 'overlay_geometry.dart';

class OrganizationZonesOverlay extends StatefulWidget {
  const OrganizationZonesOverlay({
    super.key,
    this.image,
    this.imageUrl,
    required this.objects,
    this.fit = BoxFit.cover,
    this.showBaseImage = true,
  }) : assert(
          image != null || imageUrl != null,
          'Provide either image or imageUrl',
        );

  final ImageProvider? image;
  final String? imageUrl;
  final List<DetectedObject> objects;
  final BoxFit fit;
  final bool showBaseImage;

  @override
  State<OrganizationZonesOverlay> createState() =>
      _OrganizationZonesOverlayState();
}

class _OrganizationZonesOverlayState extends State<OrganizationZonesOverlay> {
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
  void didUpdateWidget(covariant OrganizationZonesOverlay oldWidget) {
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
    final zones = _generateZones(widget.objects);

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        if (widget.showBaseImage) {
          children.add(
            Positioned.fill(
              child: Image(
                image: _imageProvider,
                fit: widget.fit,
              ),
            ),
          );
        }

        final info = _imageInfo;
        if (info == null || zones.isEmpty) {
          return Stack(children: children);
        }

        final geometry = OverlayGeometry.fromSizes(
          inputSize: Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
          outputSize: Size(constraints.maxWidth, constraints.maxHeight),
          fit: widget.fit,
        );

        for (final zone in zones) {
          final mappedRect = geometry.mapNormalizedBox(zone.box);
          if (mappedRect == null) continue;
          children.add(
            Positioned(
              left: mappedRect.left,
              top: mappedRect.top,
              width: mappedRect.width,
              height: mappedRect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: zone.color.withAlpha(56),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: zone.color, width: 1.3),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: zone.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        zone.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }

  List<_Zone> _generateZones(List<DetectedObject> objects) {
    final candidates = objects.where((obj) => obj.confidence >= 0.35).toList();
    if (candidates.length < 2) return const [];

    final groups = <String, List<DetectedObject>>{};
    for (final obj in candidates) {
      final centerX = (obj.box.left + (obj.box.width / 2)).clamp(0.0, 1.0);
      final centerY = (obj.box.top + (obj.box.height / 2)).clamp(0.0, 1.0);
      final vertical = centerY < 0.5 ? 'Upper' : 'Lower';
      final horizontal = centerX < 0.5 ? 'Left' : 'Right';
      final key = '$vertical $horizontal';
      groups.putIfAbsent(key, () => <DetectedObject>[]).add(obj);
    }

    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final palette = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFF0EA5E9),
      const Color(0xFF16A34A),
    ];

    final zones = <_Zone>[];
    for (int i = 0; i < sortedGroups.length && zones.length < 3; i++) {
      final entry = sortedGroups[i];
      final box = _envelope(entry.value);
      if (box == null) continue;
      zones.add(
        _Zone(
          name: '${entry.key} zone',
          box: box,
          color: palette[zones.length % palette.length],
        ),
      );
    }

    if (zones.isEmpty) {
      final singleBox = _envelope(candidates);
      if (singleBox != null) {
        zones.add(
          const _Zone(
            name: 'Focus zone',
            box: BoundingBoxNormalized(
              left: 0.18,
              top: 0.18,
              width: 0.64,
              height: 0.64,
            ),
            color: Color(0xFF2563EB),
          ),
        );
      }
    }

    return zones;
  }

  BoundingBoxNormalized? _envelope(List<DetectedObject> group) {
    if (group.isEmpty) return null;

    double minX = 1.0;
    double minY = 1.0;
    double maxX = 0.0;
    double maxY = 0.0;

    for (final obj in group) {
      minX = math.min(minX, obj.box.left);
      minY = math.min(minY, obj.box.top);
      maxX = math.max(maxX, obj.box.left + obj.box.width);
      maxY = math.max(maxY, obj.box.top + obj.box.height);
    }

    const pad = 0.03;
    final left = (minX - pad).clamp(0.0, 1.0);
    final top = (minY - pad).clamp(0.0, 1.0);
    final right = (maxX + pad).clamp(0.0, 1.0);
    final bottom = (maxY + pad).clamp(0.0, 1.0);
    final width = (right - left).clamp(0.0, 1.0);
    final height = (bottom - top).clamp(0.0, 1.0);
    if (width <= 0 || height <= 0) return null;

    return BoundingBoxNormalized(
      left: left,
      top: top,
      width: width,
      height: height,
    );
  }
}

class _Zone {
  const _Zone({
    required this.name,
    required this.box,
    required this.color,
  });

  final String name;
  final BoundingBoxNormalized box;
  final Color color;
}
