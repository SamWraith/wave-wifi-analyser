import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'wave_haptics.dart';
import 'wave_motion.dart';

/// Reveals the live theme beneath one frozen frame, without duplicating routes.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child, this.captureFrame});
  final Widget child;

  /// Optional readback boundary for deterministic asynchronous race tests.
  @visibleForTesting
  final Future<ui.Image> Function(RenderRepaintBoundary, double)? captureFrame;

  static Future<void> change(BuildContext origin, VoidCallback update) async {
    final state = origin.findAncestorStateOfType<_ThemeRevealState>();
    if (state == null) {
      update();
    } else {
      await state.change(origin, update);
    }
  }

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _boundary = GlobalKey();
  late final _animation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 460),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _clear();
      });
  ui.Image? _image;
  Offset _origin = Offset.zero;
  Size _size = Size.zero;
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> change(BuildContext context, VoidCallback update) async {
    if (_busy) return;
    WaveHaptics.selection();
    if (WaveMotion.reduced(context)) {
      update();
      return;
    }
    _busy = true;
    final generation = ++_generation;
    ui.Image? captured;
    bool applied = false;
    try {
      final source = context.findRenderObject();
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || !context.mounted || generation != _generation) return;
      final boundary = _boundary.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || source is! RenderBox) {
        update();
        return;
      }
      final origin = boundary.globalToLocal(
        source.localToGlobal(source.size.center(Offset.zero)),
      );
      final pixelRatio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      captured =
          await (widget.captureFrame?.call(boundary, pixelRatio) ??
              boundary.toImage(pixelRatio: pixelRatio));
      if (!mounted || !context.mounted || generation != _generation) return;
      if (WaveMotion.reduced(context)) {
        applied = true;
        update();
        return;
      }
      _animation.value = 0;
      setState(() {
        _image = captured;
        _origin = origin;
        _size = boundary.size;
      });
      captured = null; // Ownership transferred to this State.
      applied = true;
      update();
      // Wait until the new theme is painted beneath the frozen old frame.
      await SchedulerBinding.instance.endOfFrame;
      if (mounted && generation == _generation) _animation.forward(from: 0);
    } catch (_) {
      // Raster capture is optional; theme selection must still work.
      if (!applied && mounted && context.mounted && generation == _generation) {
        update();
      }
      if (mounted && generation == _generation) _clear();
    } finally {
      captured?.dispose();
      if (mounted && generation == _generation && _image == null) {
        _busy = false;
      }
    }
  }

  void _clear() {
    _animation.stop();
    _image?.dispose();
    _image = null;
    _busy = false;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _generation++;
      _clear();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = WaveMotion.reduced(context);
    final size = MediaQuery.sizeOf(context);
    if (_image != null && (reduced || size != _size)) {
      _generation++;
      _clear();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(key: _boundary, child: widget.child),
      if (_image case final image?)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                key: const ValueKey('theme-reveal-overlay'),
                painter: _RevealPainter(image, _origin, _animation),
              ),
            ),
          ),
        ),
    ],
  );
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.image, this.origin, this.animation)
    : super(repaint: animation);
  final ui.Image image;
  final Offset origin;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(
        Rect.fromCircle(
          center: origin,
          radius: radius * Curves.easeInOutCubic.transform(animation.value),
        ),
      );
    canvas.clipPath(cutout);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_RevealPainter oldDelegate) =>
      image != oldDelegate.image ||
      origin != oldDelegate.origin ||
      animation != oldDelegate.animation;
}
