import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import '../models/onboarding_step.dart';
import 'wave_motion.dart';

final onboardingArtProvider = Provider<Widget Function(OnboardingStep)>(
  (ref) =>
      (step) =>
          OnboardingIllustration(key: ValueKey(step.artboard), step: step),
);

class OnboardingIllustration extends StatefulWidget {
  const OnboardingIllustration({super.key, required this.step});
  final OnboardingStep step;

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with WidgetsBindingObserver {
  rive.File? _file;
  rive.Artboard? _artboard;
  _ExplorePainter? _painter;
  bool _failed = false;
  bool _reduced = false;
  bool _background = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _background =
        WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    unawaited(_load());
  }

  Future<void> _load() async {
    rive.File? file;
    rive.Artboard? artboard;
    _ExplorePainter? painter;
    try {
      await rive.RiveNative.init();
      if (!mounted) return;
      file = await rive.File.asset(
        widget.step.asset,
        riveFactory: rive.Factory.flutter,
      );
      if (!mounted) {
        file?.dispose();
        return;
      }
      if (file == null) throw StateError('Onboarding artwork unavailable');
      artboard = file.artboard(widget.step.artboard);
      if (artboard == null) throw StateError('Onboarding artboard unavailable');
      painter = _ExplorePainter();
      painter.artboardChanged(artboard);
      painter.setMotion(reduced: _reduced, background: _background);
      setState(() {
        _file = file;
        _artboard = artboard;
        _painter = painter;
      });
    } catch (error, stack) {
      painter?.dispose();
      artboard?.dispose();
      file?.dispose();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Wave onboarding',
          context: ErrorDescription('loading onboarding artwork'),
        ),
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = WaveMotion.reduced(context);
    _painter?.setMotion(reduced: _reduced, background: _background);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _painter?.setMotion(reduced: _reduced, background: _background);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _painter?.dispose();
    _artboard?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.2,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: _artboard == null || painter == null
                  ? Center(
                      child: Icon(
                        widget.step.icon,
                        size: 100,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : rive.RiveArtboardWidget(
                      artboard: _artboard!,
                      painter: painter,
                    ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: painter == null || _reduced ? null : painter.replay,
          icon: const Icon(Icons.touch_app_rounded, size: 18),
          label: Text(
            _failed
                ? 'Illustration unavailable'
                : _reduced
                ? 'Motion reduced'
                : widget.step.action,
          ),
        ),
      ],
    );
  }
}

/// Plays authored keyframes once, then rests. Replay requires explicit intent.
final class _ExplorePainter extends rive.BasicArtboardPainter {
  rive.Animation? _animation;
  double _elapsed = 0;
  bool _reduced = false, _background = false;

  @override
  void artboardChanged(rive.Artboard artboard) {
    if (identical(this.artboard, artboard)) return;
    super.artboardChanged(artboard);
    _animation?.dispose();
    _animation = artboard.animationNamed('Explore');
    if (_animation == null) throw StateError('Explore animation unavailable');
  }

  void setMotion({required bool reduced, required bool background}) {
    _reduced = reduced;
    _background = background;
    if (reduced) _elapsed = _animation?.duration ?? 0;
    scheduleRepaint();
  }

  void replay() {
    if (_reduced || _background) return;
    _elapsed = 0;
    scheduleRepaint();
  }

  @override
  bool advance(double elapsedSeconds) {
    final animation = _animation;
    if (animation == null) return false;
    if (!_background && !_reduced) _elapsed += elapsedSeconds;
    animation.time = math.min(_elapsed, animation.duration);
    animation.apply();
    artboard?.advance(0);
    return !_background && !_reduced && _elapsed < animation.duration;
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }
}
