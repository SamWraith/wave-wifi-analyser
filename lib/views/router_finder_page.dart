import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/ap_preference.dart';
import '../models/router_finder.dart';
import '../models/wifi_data_source.dart';
import '../viewmodels/analyser_view_model.dart';
import '../viewmodels/router_finder_view_model.dart';
import '../widgets/scan_freshness.dart';
import '../widgets/wave_components.dart';

class RouterFinderPage extends ConsumerWidget {
  const RouterFinderPage({super.key, required this.target});
  final AccessPoint target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(routerFinderProvider(target));
    final scan = ref.watch(
      analyserProvider.select(
        (s) => (
          source: s.source,
          paused: s.paused,
          busy: s.busy,
          cached: s.cached,
          points: s.accessPoints,
          updated: s.lastUpdated,
          status: s.status,
        ),
      ),
    );
    final seen = scan.points.any(
      (ap) => preferenceKey(ap.bssid) == preferenceKey(target.bssid),
    );
    final blocked = session.sourceChanged || scan.paused;
    final status = session.sourceChanged
        ? 'Data source changed. Close finder and select an access point again.'
        : scan.paused
        ? 'Scanning paused. Resume to collect more observations.'
        : !seen
        ? 'Target not seen in current results. Last observation retained.'
        : scan.cached || scan.updated != session.updated
        ? 'Waiting for a new accepted target observation.'
        : 'Compare signal after each update, then try another direction.';
    return Scaffold(
      appBar: AppBar(title: const Text('Router finder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WavePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText('BSSID ${target.bssid}'),
                      const SizedBox(height: 8),
                      Text(scan.source.evidenceLabel),
                      const SizedBox(height: 20),
                      _FinderSignal(
                        session: session,
                        blocked:
                            blocked ||
                            !seen ||
                            scan.cached ||
                            scan.updated != session.updated,
                      ),
                      const SizedBox(height: 16),
                      Text(status),
                      const SizedBox(height: 12),
                      ScanFreshness(
                        updated: session.updated,
                        demo: scan.source == WifiDataSource.demo,
                        source: scan.source,
                        cached:
                            scan.cached ||
                            !seen ||
                            scan.updated != session.updated,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: blocked || scan.busy
                                ? null
                                : () => ref
                                      .read(analyserProvider.notifier)
                                      .scan(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              scan.busy ? 'Scanning…' : 'Request scan',
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                session.sourceChanged || session.samples == 0
                                ? null
                                : ref
                                      .read(
                                        routerFinderProvider(target).notifier,
                                      )
                                      .reset,
                            child: const Text('Start comparison here'),
                          ),
                          if (scan.paused)
                            TextButton(
                              onPressed: ref
                                  .read(analyserProvider.notifier)
                                  .togglePause,
                              child: const Text('Resume scans'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        scan.status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const WavePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'Walk, pause, compare',
                        subtitle:
                            'A signal guide, not a compass or measured range',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Move a few steps, hold your device the same way and wait for an update. Stronger signal may suggest you are nearer; walls, reflections and transmit power can mislead.',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Automatic live requests are 35 seconds apart. Android or your driver may delay them further. Repeated requests cannot force fresh results. Desktop per-network radio freshness is unknown.',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tracks this BSSID, not every router sharing its WiFi name. A frequency change restarts the comparison. Finder comparison resets when this screen closes; nothing is saved or exported by finder.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinderSignal extends StatelessWidget {
  const _FinderSignal({required this.session, required this.blocked});
  final RouterFinderState session;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final ap = session.latest;
    final estimate = ap?.distance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ap == null ? '— dBm' : '${ap.rssi} dBm',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(blocked ? 'Guidance on hold' : session.guidance),
        if (ap != null) ...[
          const SizedBox(height: 12),
          Text(
            'Start ${session.baselineRssi} dBm · Best ${session.bestRssi} dBm',
          ),
          Text('${session.samples} accepted observations'),
          if (estimate != null && estimate.isFinite)
            Text(
              'Free-space estimate ~${estimate.toStringAsFixed(1)} m • can be very inaccurate indoors',
            ),
        ],
      ],
    );
  }
}
