import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../viewmodels/comparison_sessions_view_model.dart';
import '../widgets/wave_components.dart';
import 'analyser_providers.dart';
import '../widgets/connection_card.dart';
import '../widgets/network_tile.dart';
import 'chart_panel.dart';
import 'chart_selection.dart';
import 'wifi_guidance_sheet.dart';
import 'sessions_page.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({
    super.key,
    required this.onViewNetworks,
    this.onOpenSpectrum,
    this.selection,
  });
  final VoidCallback onViewNetworks;
  final VoidCallback? onOpenSpectrum;
  final ChartSelection? selection;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const OverviewSummary(),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => showWifiGuidance(context),
            icon: const Icon(Icons.wifi_find_rounded),
            label: const Text('Improve my WiFi'),
          ),
          const RoomComparisonButton(),
        ],
      ),
      const SizedBox(height: 22),
      ChartPanel(
        compactLegend: true,
        selection: selection,
        onOpenSpectrum: onOpenSpectrum,
      ),
      const SizedBox(height: 22),
      ResponsivePair(
        breakpoint:
            760 * (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2),
        first: const NetworkInsights(),
        second: NearbyNetworks(onViewAll: onViewNetworks),
      ),
    ],
  );
}

class RoomComparisonButton extends ConsumerWidget {
  const RoomComparisonButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      comparisonSessionsProvider.select(
        (s) => (s.active?.id, s.active?.label, s.active?.demo),
      ),
    );
    final label = active.$1 == null
        ? 'Compare rooms'
        : active.$2?.isNotEmpty == true
        ? 'Recording · ${active.$2}'
        : 'Recording session';
    return OutlinedButton.icon(
      onPressed: () => showComparisonSessions(context),
      icon: Icon(
        active.$1 == null
            ? Icons.compare_arrows_rounded
            : Icons.fiber_manual_record_rounded,
      ),
      label: Text(
        active.$3 == true && active.$1 != null ? '$label (simulated)' : label,
      ),
    );
  }
}

class OverviewSummary extends ConsumerWidget {
  const OverviewSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(connectedPointProvider);
    final demo = ref.watch(analyserProvider.select((state) => state.demo));
    final band = ref.watch(analyserProvider.select((state) => state.band));
    final count = ref.watch(
      bandPointsProvider.select((points) => points.length),
    );
    final ratings = ref.watch(channelRatingsProvider);
    return ResponsivePair(
      breakpoint:
          680 * (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2),
      firstFlex: 3,
      secondFlex: 2,
      spacing: 18,
      first: ConnectionCard(ap: ap, demo: demo),
      second: Column(
        children: [
          MetricCard(
            label: 'NEARBY NETWORKS',
            value: '$count',
            note: 'On ${band.label}',
            icon: Icons.radar_rounded,
            accent: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 14),
          MetricCard(
            label: 'CLEAREST CANDIDATE',
            value: count == 0 ? '—' : 'CH ${ratings.first.channel}',
            note: 'Relative overlap estimate',
            icon: Icons.auto_awesome_outlined,
            accent: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class NearbyNetworks extends ConsumerWidget {
  const NearbyNetworks({super.key, required this.onViewAll});
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(visiblePointsProvider);
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Nearby networks',
            subtitle: 'Strongest signals in this band',
            trailing: TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const EmptyState(text: 'No networks in this band'),
          ...points
              .take(3)
              .map((ap) => NetworkTile(key: ValueKey(ap.bssid), ap: ap)),
        ],
      ),
    );
  }
}

class NetworkInsights extends ConsumerWidget {
  const NetworkInsights({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(connectedPointProvider);
    final points = ref.watch(bandPointsProvider);
    final ratings = ref.watch(channelRatingsProvider);
    final open = points
        .where((a) => a.security == 'Open' || a.security == 'WEP')
        .length;
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Network insights',
            subtitle: 'Local rules. Clear next steps.',
            trailing: Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 20),
          InsightTile(
            icon: Icons.signal_cellular_alt_rounded,
            accent: Theme.of(context).colorScheme.secondary,
            title: ap == null
                ? 'No connected AP identified'
                : '${ap.quality} signal',
            text: ap == null
                ? 'Scan while connected to WiFi. Your operating system may withhold connection identity.'
                : ap.rssi < -70
                ? 'Move closer to your access point and compare signal history.'
                : 'Signal looks healthy at your current location.',
          ),
          const SizedBox(height: 18),
          InsightTile(
            icon: Icons.layers_outlined,
            accent: Theme.of(context).colorScheme.tertiary,
            title: 'Channel planning',
            text: points.isEmpty
                ? 'Run a scan before comparing channels.'
                : 'Channel ${ratings.first.channel} has lowest estimated overlap among shown candidates. Verify your router supports it.',
          ),
          const SizedBox(height: 18),
          InsightTile(
            icon: Icons.shield_outlined,
            title: open > 0
                ? '$open open or legacy networks'
                : 'Security check',
            text: open > 0
                ? 'Open and WEP networks deserve caution. Prefer WPA2 or WPA3.'
                : 'Use WPA2 or WPA3 on your router. This checks advertised security only.',
          ),
        ],
      ),
    );
  }
}
