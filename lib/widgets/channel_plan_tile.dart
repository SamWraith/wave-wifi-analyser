import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ap_preference.dart';
import '../models/access_point.dart';
import '../models/channel_plan.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import 'wave_haptics.dart';
import 'wave_motion.dart';

class ChannelPlanTile extends ConsumerWidget {
  const ChannelPlanTile({super.key, required this.plan, required this.amount});
  final ChannelPlan plan;
  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    expansionAnimationStyle: WaveMotion.sheetStyle(context),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    onExpansionChanged: (_) => WaveHaptics.selection(),
    title: Text('CH ${plan.channel} • center ${plan.center} MHz'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${plan.width} MHz${plan.width == 40 && plan.center < 2500 ? ' • extension ${plan.center > planningFrequency(WifiBand.ghz24, plan.channel)! ? 'above' : 'below'}' : ''} • relative overlap ${plan.score > 0 && plan.score < .01 ? '<0.01' : plan.score.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: amount),
          duration: WaveMotion.duration(context, 300),
          curve: WaveMotion.curve,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            semanticsLabel:
                'Overlap relative to highest candidate in this plan',
            semanticsValue: '${(amount * 100).round()}%',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          plan.contributors.isEmpty
              ? 'No observed overlap • tap for limits'
              : '${plan.contributorCount} contributing APs • tap for reasons',
        ),
      ],
    ),
    children: [
      if (plan.contributors.isEmpty)
        const Text(
          'No overlap from observed APs under these assumptions. Unseen networks, noise and traffic are not measured.',
        )
      else ...[
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Strongest overlap contributors'),
        ),
        for (final contributor in plan.contributors.take(3))
          _ContributorRow(contributor: contributor, total: plan.score),
        if (plan.contributorCount > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${plan.contributorCount - 3} other APs also included in total.',
            ),
          ),
      ],
    ],
  );
}

class _ContributorRow extends ConsumerWidget {
  const _ContributorRow({required this.contributor, required this.total});
  final OverlapContributor contributor;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = contributor.ap;
    final alias = ref.watch(
      apPreferencesProvider.select(
        (s) => s.entries[preferenceKey(ap.bssid)]?.alias,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${alias == null ? ap.name : '$alias • ${ap.name}'}\n'
          '${ap.bssid} • CH ${ap.channel} • ${ap.rssi} dBm\n'
          'Reported ${ap.width} MHz • primary ${ap.frequency} MHz • '
          '${ap.centerFrequency == null || ap.centerFrequency! <= 0 ? 'center unavailable; using primary' : 'center ${ap.centerFrequency} MHz'}\n'
          '${(contributor.score / total * 100).round()}% of this candidate’s overlap',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
