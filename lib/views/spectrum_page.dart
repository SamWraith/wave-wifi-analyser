import 'package:flutter/material.dart';

import '../widgets/wave_components.dart';
import 'chart_panel.dart';
import 'chart_selection.dart';

class SpectrumPage extends StatelessWidget {
  const SpectrumPage({super.key, this.selection});
  final ChartSelection? selection;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ChartPanel(selection: selection),
      const SizedBox(height: 18),
      WavePanel(
        child: Text(
          'Chart envelopes illustrate reported center frequency and channel width. Signal strength is measured at this device; overlap does not measure internet speed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
