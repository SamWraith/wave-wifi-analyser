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

class ChartPanel extends ConsumerStatefulWidget {
  const ChartPanel({super.key, this.compactLegend = false});
  final bool compactLegend;
  @override
  ConsumerState<ChartPanel> createState() => _ChartPanelState();
}

enum _LegendPhase { hidden, restored }

class _ChartPanelState extends ConsumerState<ChartPanel> {
  bool timeGraph = false;
  final Map<String, _LegendPhase> _phases = {};
  String? _soloBssid;

  void _resetLegend() {
    _phases.clear();
    _soloBssid = null;
  }

  void _cycleLegend(String bssid, Set<String> visibleIds) {
    WaveHaptics.selection();
    setState(() {
      final currentIds = ref
          .read(accessPointsProvider)
          .map((ap) => ap.bssid)
          .toSet();
      _phases.removeWhere((id, _) => !currentIds.contains(id));
      if (!visibleIds.contains(_soloBssid)) _soloBssid = null;
      if (_soloBssid != null) {
        if (_soloBssid == bssid) {
          _resetLegend();
        } else {
          _soloBssid = bssid;
        }
        return;
      }
      switch (_phases[bssid]) {
        case null:
          _phases[bssid] = _LegendPhase.hidden;
        case _LegendPhase.hidden:
          _phases[bssid] = _LegendPhase.restored;
        case _LegendPhase.restored:
          _soloBssid = bssid;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(visiblePointsProvider);
    final band = ref.watch(analyserProvider.select((state) => state.band));
    final history = ref.watch(
      analyserProvider.select((state) => state.history),
    );
    final visibleIds = points.map((ap) => ap.bssid).toSet();
    final solo = visibleIds.contains(_soloBssid) ? _soloBssid : null;
    final hidden = {
      for (final ap in points)
        if (solo != null
            ? ap.bssid != solo
            : _phases[ap.bssid] == _LegendPhase.hidden)
          ap.bssid,
    };
    final legendItems = <Widget>[
      for (final ap in points)
        ChartLegendItem(
          key: ValueKey(ap.bssid),
          point: ap,
          compact: widget.compactLegend,
          visible: !hidden.contains(ap.bssid),
          solo: solo == ap.bssid,
          nextAction: solo == ap.bssid
              ? 'Show all networks'
              : solo != null || _phases[ap.bssid] == _LegendPhase.restored
              ? 'Show only this network'
              : hidden.contains(ap.bssid)
              ? 'Include this network'
              : 'Exclude this network',
          onTap: () => _cycleLegend(ap.bssid, visibleIds),
        ),
    ];
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
                hiddenBssids: hidden,
              ),
            ),
            const SizedBox(height: 12),
            ChartLegend(
              compact: widget.compactLegend,
              items: legendItems,
              onReset: _phases.isEmpty && _soloBssid == null
                  ? null
                  : () {
                      WaveHaptics.selection();
                      setState(_resetLegend);
                    },
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
