import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import 'wave_motion.dart';

/// One bounded pulse per fresh scan; no idle animation or extra scan timer.
class ScanActivity extends ConsumerWidget {
  const ScanActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (demo, paused, updated) = ref.watch(
      analyserProvider.select((s) => (s.demo, s.paused, s.lastUpdated)),
    );
    final color = demo
        ? const Color(0xFFCA914C)
        : Theme.of(context).colorScheme.primary;
    final icon = Icon(
      paused
          ? Icons.pause_rounded
          : demo
          ? Icons.science_outlined
          : Icons.sensors_rounded,
      size: 18,
      color: color,
    );
    if (paused || updated == null || WaveMotion.reduced(context)) {
      return SizedBox(width: 28, height: 28, child: Center(child: icon));
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey((demo, updated)),
      tween: Tween(begin: 0, end: 1),
      duration: WaveMotion.duration(context, 600),
      child: icon,
      builder: (context, value, child) => SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: .5 + value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: .5 * (1 - value)),
                  ),
                ),
              ),
            ),
            child!,
          ],
        ),
      ),
    );
  }
}
