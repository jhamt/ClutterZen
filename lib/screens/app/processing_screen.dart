import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../services/i18n_service.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, this.background, this.onReady});

  final ImageProvider? background; // optional blurred backdrop
  final Future<void> Function(BuildContext context)?
      onReady; // optional task to run then navigate

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  static const _lottieUrl =
      'https://lottie.host/0bd5139f-6801-4bfe-abdf-e4e03d90ab03/2DCtc5jJKu.json';
  List<String> get _steps => [
        I18nService.translate("Detecting objects..."),
        I18nService.translate("Analyzing clutter level..."),
        I18nService.translate("Generating solutions..."),
      ];
  List<String> get _tips => [
        I18nService.translate(
            "Tip: Group similar items to reduce visual noise."),
        I18nService.translate("Tip: Clear flat surfaces first for fast wins."),
        I18nService.translate(
            "Tip: Label bins to keep organization sustainable."),
      ];

  int _currentStep = 0;
  int _tipIndex = 0;
  Timer? _stepTimer;
  Timer? _tipTimer;
  bool _taskCompleted = false;

  @override
  void initState() {
    super.initState();
    _startProgressTimers();

    // Kick off async task if provided, after first frame to ensure context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cb = widget.onReady;
      if (cb == null) return;
      await cb(context);
      if (!mounted) return;
      setState(() {
        _taskCompleted = true;
        _currentStep = _steps.length; // mark all steps complete exactly once
      });
      _stepTimer?.cancel();
    });
  }

  void _startProgressTimers() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) return;
      setState(() {
        if (_taskCompleted) {
          _currentStep = _steps.length;
          t.cancel();
          return;
        }

        // Advance only forward and never loop back to first step.
        if (_currentStep < _steps.length - 1) {
          _currentStep += 1;
        } else if (widget.onReady == null) {
          // If no async task is attached, allow the final step to complete.
          _currentStep = _steps.length;
          t.cancel();
        }
      });
    });

    _tipTimer = Timer.periodic(const Duration(milliseconds: 2200), (t) {
      if (!mounted) return;
      setState(() {
        _tipIndex = (_tipIndex + 1) % _tips.length;
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18nService.translate("Processing")),
        actions: [
          Row(children: [
            Icon(Icons.camera_alt_outlined),
            SizedBox(width: 4),
            Text(I18nService.translate("3")),
            SizedBox(width: 12)
          ])
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.background != null
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                        Colors.black.withAlpha(128), BlendMode.srcATop),
                    child: Image(image: widget.background!, fit: BoxFit.cover),
                  )
                : Container(color: Colors.grey[800]),
          ),
          Center(
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 16,
                      offset: const Offset(0, 8))
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 150,
                      height: 150,
                      child: Lottie.network(_lottieUrl, repeat: true)),
                  const SizedBox(height: 16),
                  Text(I18nService.translate("Analyzing Your Image"),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  // Steps
                  for (int i = 0; i < _steps.length; i++)
                    _ProcessingStep(
                        text: _steps[i],
                        isActive: !_taskCompleted && _currentStep == i,
                        isComplete: _currentStep > i ||
                            (_taskCompleted && i == _steps.length - 1)),
                  const SizedBox(height: 16),
                  Text(_tips[_tipIndex],
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep(
      {required this.text, required this.isActive, required this.isComplete});
  final String text;
  final bool isActive;
  final bool isComplete;
  @override
  Widget build(BuildContext context) {
    Widget icon;
    if (isComplete) {
      icon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (isActive) {
      icon = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      icon = Icon(Icons.circle_outlined, color: Colors.grey[400], size: 20);
    }
    final style = isActive
        ? Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: style))
        ],
      ),
    );
  }
}
