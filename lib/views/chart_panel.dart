import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_motion.dart';
import 'analyser_providers.dart';
import '../widgets/signal_charts.dart';

class ChartPanel extends ConsumerStatefulWidget {
  const ChartPanel({super.key});
  @override
  ConsumerState<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends ConsumerState<ChartPanel> {
  bool timeGraph = false;
  @override
  Widget build(BuildContext context) {
    final points = ref.watch(visiblePointsProvider);
    final band = ref.watch(analyserProvider.select((state) => state.band));
    final history = ref.watch(
      analyserProvider.select((state) => state.history),
    );
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: timeGraph ? 'Signal over time' : 'Channel landscape',
            subtitle: timeGraph
                ? 'Fresh scan samples only • up to 60 per access point'
                : 'Signal strength across ${band.label}',
            trailing: IconButton(
              tooltip: timeGraph ? 'Show channel graph' : 'Show signal history',
              onPressed: () => setState(() => timeGraph = !timeGraph),
              icon: Icon(
                timeGraph ? Icons.stacked_line_chart : Icons.timeline_rounded,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (points.isEmpty)
            EmptyState(
              text: 'No scan results yet. Scan nearby networks or enable demo in Settings.',
            )
          else ...[
            WaveReveal(
              key: ValueKey((timeGraph, band)),
              child: SignalChart(
                points: points,
                band: band,
                history: history,
                time: timeGraph,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: points
                  .take(8)
                  .map(
                    (ap) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: pointColor(ap),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ap.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            if (timeGraph && history.isEmpty)
              Text(
                'History begins with the next fresh scan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}
