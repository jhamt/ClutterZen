import 'package:flutter/material.dart';

import '../../../services/i18n_service.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 320,
    this.onAfterStateChanged,
  });

  final ImageProvider before;
  final ImageProvider after;
  final double height;
  final ValueChanged<bool>? onAfterStateChanged;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;
  bool _afterFailed = false;
  bool _afterLoading = true;
  String? _lastAfterFailureIdentity;

  void _setAfterFailed(bool failed) {
    if (_afterFailed == failed) return;
    _afterFailed = failed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      widget.onAfterStateChanged?.call(failed);
    });
  }

  void _setAfterLoading(bool loading) {
    if (_afterLoading == loading) return;
    _afterLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant BeforeAfterSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.after != widget.after) {
      _afterLoading = true;
      _lastAfterFailureIdentity = null;
      _setAfterFailed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) {
          return const SizedBox.shrink();
        }
        const handleDiameter = 40.0;
        const handleRadius = handleDiameter / 2;
        final minRatio = width <= handleDiameter ? 0.5 : handleRadius / width;
        final maxRatio = width <= handleDiameter ? 0.5 : 1 - minRatio;
        final safePosition = _position.clamp(minRatio, maxRatio).toDouble();
        final handleCenter = width * safePosition;
        final dividerX = handleCenter.clamp(0.0, width).toDouble();
        final handleLeft = handleCenter - handleRadius;
        final afterIdentity = widget.after.toString();
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (width <= 0) return;
            setState(() {
              _position = (_position + (details.delta.dx / width))
                  .clamp(minRatio, maxRatio);
            });
          },
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFEFF2F6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image(
                      image: widget.after,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          _setAfterLoading(false);
                          return child;
                        }
                        _setAfterLoading(true);
                        return child;
                      },
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        if (wasSyncLoaded || frame != null) {
                          _setAfterLoading(false);
                          _setAfterFailed(false);
                        }
                        return child;
                      },
                      errorBuilder: (context, _, __) {
                        _setAfterLoading(false);
                        if (_lastAfterFailureIdentity != afterIdentity) {
                          _lastAfterFailureIdentity = afterIdentity;
                          _setAfterFailed(true);
                        }
                        return Container(
                          color: const Color(0xFFF8FAFC),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF98A2B3),
                            size: 34,
                          ),
                        );
                      },
                    ),
                  ),
                  if (!_afterFailed)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: safePosition,
                        child: SizedBox(
                          width: width,
                          child: Image(
                            image: widget.before,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) {
                              return Container(
                                color: const Color(0xFFF8FAFC),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Color(0xFF98A2B3),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (_afterLoading && !_afterFailed)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: const Color(0x66000000),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  if (!_afterFailed) ...[
                    Positioned(
                      left: dividerX - 1.5,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 3, color: Colors.white),
                    ),
                    Positioned(
                      left: handleLeft,
                      top: (widget.height / 2) - 20,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD0D5DD),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(70),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.compare_arrows,
                            color: Color(0xFF111111)),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _chip('BEFORE', const Color(0xFFD92D20)),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _chip('AFTER', const Color(0xFF16A34A)),
                    ),
                  ],
                  if (_afterFailed)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: const Color(0xB3FFFFFF),
                          alignment: Alignment.center,
                          child: Text(
                            I18nService.translate(
                                'Organized image unavailable'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFFB42318),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
