import 'package:flutter/painting.dart';

import '../models/vision_models.dart';

class OverlayGeometry {
  const OverlayGeometry({
    required this.inputRect,
    required this.sourceRect,
    required this.destinationRect,
  });

  final Rect inputRect;
  final Rect sourceRect;
  final Rect destinationRect;

  factory OverlayGeometry.fromSizes({
    required Size inputSize,
    required Size outputSize,
    required BoxFit fit,
  }) {
    final fitted = applyBoxFit(fit, inputSize, outputSize);
    final inputRect = Offset.zero & inputSize;
    final outputRect = Offset.zero & outputSize;
    final sourceRect = Alignment.center.inscribe(fitted.source, inputRect);
    final destinationRect =
        Alignment.center.inscribe(fitted.destination, outputRect);
    return OverlayGeometry(
      inputRect: inputRect,
      sourceRect: sourceRect,
      destinationRect: destinationRect,
    );
  }

  Rect? mapNormalizedBox(BoundingBoxNormalized box) {
    final leftNorm = box.left.clamp(0.0, 1.0);
    final topNorm = box.top.clamp(0.0, 1.0);
    final rightNorm = (box.left + box.width).clamp(0.0, 1.0);
    final bottomNorm = (box.top + box.height).clamp(0.0, 1.0);

    final absolute = Rect.fromLTRB(
      inputRect.left + (leftNorm * inputRect.width),
      inputRect.top + (topNorm * inputRect.height),
      inputRect.left + (rightNorm * inputRect.width),
      inputRect.top + (bottomNorm * inputRect.height),
    );

    final visibleAbsolute = absolute.intersect(sourceRect);
    if (visibleAbsolute.width <= 0 || visibleAbsolute.height <= 0) {
      return null;
    }

    final scaleX = destinationRect.width / sourceRect.width;
    final scaleY = destinationRect.height / sourceRect.height;

    final projected = Rect.fromLTRB(
      destinationRect.left + (visibleAbsolute.left - sourceRect.left) * scaleX,
      destinationRect.top + (visibleAbsolute.top - sourceRect.top) * scaleY,
      destinationRect.left + (visibleAbsolute.right - sourceRect.left) * scaleX,
      destinationRect.top + (visibleAbsolute.bottom - sourceRect.top) * scaleY,
    );

    final clipped = projected.intersect(destinationRect);
    if (clipped.width <= 0 || clipped.height <= 0) {
      return null;
    }
    return clipped;
  }
}
