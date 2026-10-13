import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/wave_motion.dart';
import 'analyser_navigation.dart';
import 'chart_panel.dart';
import 'chart_selection.dart';

void openFocusedSpectrum(BuildContext context, ChartSelection selection) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: WaveMotion.duration(context, 220),
      reverseTransitionDuration: WaveMotion.duration(context, 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          FocusedSpectrumPage(selection: selection),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class FocusedSpectrumPage extends StatelessWidget {
  const FocusedSpectrumPage({super.key, required this.selection});
  final ChartSelection selection;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.pop(context),
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Spectrum focus'),
          actions: [
            IconButton(
              tooltip: 'Close focus',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const ScanStatusBar(),
                const SizedBox(height: 16),
                const BandSelector(),
                const SizedBox(height: 16),
                ChartPanel(selection: selection, focused: true),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
