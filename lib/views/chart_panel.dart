import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_motion.dart';
import 'analyser_providers.dart';
import '../widgets/signal_charts.dart';
import '../widgets/chart_legend_item.dart';
import '../widgets/chart_legend.dart';
import '../widgets/wave_haptics.dart';
import 'chart_selection.dart';
import 'focused_spectrum_page.dart';

class ChartPanel extends ConsumerStatefulWidget {
  const ChartPanel({
    super.key,
    this.compactLegend = false,
    this.selection,
    this.onOpenSpectrum,
    this.focused = false,
  });
  final bool compactLegend;
  final ChartSelection? selection;
  final VoidCallback? onOpenSpectrum;
  final bool focused;
  @override
  ConsumerState<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends ConsumerState<ChartPanel> {
  late final ChartSelection _local = ChartSelection();
  ChartSelection get selection => widget.selection ?? _local;

  @override
  void dispose() {
    _local.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final timeGraph = selection.timeGraph;
      final source = ref.watch(analyserProvider.select((s) => s.source));
      final points = ref.watch(visiblePointsProvider);
      final band = ref.watch(analyserProvider.select((state) => state.band));
      final history = ref.watch(
        analyserProvider.select((state) => state.history),
      );
      final visibleIds = points.map((ap) => ap.bssid).toSet();
      final solo = selection.solo(visibleIds);
      final hidden = selection.hidden(visibleIds);
      final legendItems = <Widget>[
        for (final ap in points)
          ChartLegendItem(
            key: ValueKey(ap.bssid),
            point: ap,
            compact: widget.compactLegend,
            visible: !hidden.contains(ap.bssid),
            solo: solo == ap.bssid,
            nextAction: selection.nextAction(ap.bssid, visibleIds),
            onTap: () {
              WaveHaptics.selection();
              selection.cycle(
                ap.bssid,
                visibleIds,
                ref.read(accessPointsProvider).map((ap) => ap.bssid).toSet(),
              );
            },
          ),
      ];
      return WavePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(
              title: timeGraph ? 'Signal over time' : 'Channel landscape',
              subtitle: timeGraph
                  ? source.usesCompletionTime
                        ? 'Completed scans • per-AP age unknown • up to 60 per AP'
                        : 'Fresh scan samples only • up to 60 per access point'
                  : 'Signal strength across ${band.label}',
              trailing: IconButton(
                tooltip: timeGraph
                    ? 'Show channel graph'
                    : 'Show signal history',
                onPressed: () {
                  WaveHaptics.selection();
                  selection.toggleGraph();
                },
                icon: Icon(
                  timeGraph ? Icons.stacked_line_chart : Icons.timeline_rounded,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (widget.onOpenSpectrum != null)
                  TextButton.icon(
                    onPressed: widget.onOpenSpectrum,
                    icon: const Icon(Icons.arrow_outward_rounded),
                    label: const Text('Open Spectrum'),
                  ),
                if (!widget.compactLegend && !widget.focused)
                  TextButton.icon(
                    onPressed: () {
                      WaveHaptics.selection();
                      openFocusedSpectrum(context, selection);
                    },
                    icon: const Icon(Icons.fullscreen_rounded),
                    label: const Text('Focus chart'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              EmptyState(
                text: 'No scan results yet. Scan nearby networks or enable demo in Settings.',
              )
            else ...[
              WaveReveal(
                key: ValueKey((timeGraph, band)),
                child: SignalChart(
                  height: widget.focused
                      ? (MediaQuery.sizeOf(context).height * .52).clamp(
                          320,
                          720,
                        )
                      : 270,
                  onEscape: widget.focused
                      ? () => Navigator.pop(context)
                      : null,
                  points: points,
                  band: band,
                  history: history,
                  time: timeGraph,
                  hiddenBssids: hidden,
                ),
              ),
              const SizedBox(height: 12),
              ChartLegend(
                compact: widget.compactLegend,
                items: legendItems,
                onReset: !selection.canReset
                    ? null
                    : () {
                        WaveHaptics.selection();
                        selection.reset();
                      },
              ),
              if (timeGraph && history.isEmpty)
                Text(
                  source.usesCompletionTime
                      ? 'History begins with the next completed scan; radio freshness is unknown.'
                      : 'History begins with the next fresh scan.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      );
    },
  );
}
