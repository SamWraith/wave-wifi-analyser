import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../viewmodels/channel_planning_view_model.dart';
import '../widgets/channel_plan_list.dart';
import '../widgets/channel_planning_controls.dart';
import '../widgets/scan_freshness.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_haptics.dart';
import 'analyser_providers.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(channelPlansProvider);
    final assumptions = ref.watch(selectedPlanningAssumptionsProvider);
    final hasPoints = ref.watch(
      bandPointsProvider.select((points) => points.isNotEmpty),
    );
    final (band, exclude, updated, demo, cached, paused, status) = ref.watch(
      analyserProvider.select(
        (s) => (
          s.band,
          s.excludeConnected,
          s.lastUpdated,
          s.demo,
          s.cached,
          s.paused,
          s.status,
        ),
      ),
    );
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Channel planning',
            subtitle: 'Compare overlap, then inspect what contributes.',
          ),
          const SizedBox(height: 16),
          ScanFreshness(updated: updated, demo: demo, cached: cached),
          Text(
            paused
                ? 'Paused • retained observations only. Resume scanning to recheck.'
                : status,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ChannelPlanningControls(band: band, assumptions: assumptions),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Plan for connected network'),
            subtitle: const Text(
              'Exclude only your connected BSSID from scoring',
            ),
            value: exclude,
            onChanged: (value) {
              WaveHaptics.selection();
              ref.read(analyserProvider.notifier).setExclude(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'All observed APs in this band count. Search, signal filters and hidden chart curves do not change scoring.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (!hasPoints)
            const EmptyState(
              text: 'No observations in this band. Scan or select a band with results before planning.',
            )
          else if (plans.isEmpty)
            const EmptyState(
              text: 'No candidates fit this width. Change assumptions or reset this band.',
            )
          else
            ChannelPlanList(
              key: ValueKey(
                '$band:${assumptions.width}:${assumptions.channels.join(',')}',
              ),
              plans: plans,
            ),
          const SizedBox(height: 16),
          const Text(
            'Next: check your router’s supported channels, region and DFS rules. If you choose a change in its settings, return here for a fresh scan and compare.',
          ),
          const SizedBox(height: 8),
          Text(
            'Relative overlap heuristic using bandwidth and received power. Bars compare candidates within this plan only; lower is not guaranteed improvement. This is not measured interference, noise, traffic or throughput. Reported AP widths/centers are preserved; one center cannot describe both lobes of 80+80 MHz.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
