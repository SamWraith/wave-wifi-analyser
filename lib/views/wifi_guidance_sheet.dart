import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wifi_guidance.dart';
import '../viewmodels/analyser_view_model.dart';
import '../viewmodels/wifi_guidance_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_haptics.dart';
import 'analyser_navigation.dart';

void showWifiGuidance(BuildContext context) {
  WaveHaptics.selection();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const WifiGuidanceSheet(),
  );
}

class WifiGuidanceSheet extends ConsumerWidget {
  const WifiGuidanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(wifiGuidanceProvider);
    final (busy, paused) = ref.watch(
      analyserProvider.select((s) => (s.busy, s.paused)),
    );
    final vm = ref.read(wifiGuidanceProvider.notifier);
    final baseline = guide.baseline;
    final current = guide.current;
    return FractionallySizedBox(
      heightFactor: .92,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Improve my WiFi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close troubleshooting',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a problem, try one change, then request a fresh recheck. Checks stay on this device.',
            ),
            const SizedBox(height: 16),
            const ScanStatusBar(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final problem in WifiProblem.values)
                  ChoiceChip(
                    label: Text(
                      problem == WifiProblem.weakSignal
                          ? 'Weak signal'
                          : 'Crowded channel',
                    ),
                    selected: guide.problem == problem,
                    onSelected: (_) {
                      WaveHaptics.selection();
                      vm.choose(problem);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (guide.message != null) ...[
              Text(guide.message!),
              const SizedBox(height: 16),
            ],
            if (baseline != null) ...[
              GuidanceEvidenceCard(
                title: 'Before your change',
                evidence: baseline,
              ),
              const SizedBox(height: 16),
              Text('Try this', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(guidanceAction(guide.problem!, baseline)),
              const SizedBox(height: 16),
            ],
            if (current != null) ...[
              GuidanceEvidenceCard(
                title: 'Recheck observation',
                evidence: current,
              ),
              const SizedBox(height: 12),
              Text(guidanceComparison(guide.problem!, baseline!, current)),
              const SizedBox(height: 16),
            ],
            if (guide.problem != null)
              FilledButton.icon(
                onPressed: busy || paused
                    ? null
                    : () {
                        WaveHaptics.impact();
                        vm.recheck();
                      },
                icon: const Icon(Icons.refresh),
                label: Text(
                  baseline == null
                      ? 'Get fresh scan'
                      : guide.waiting
                      ? 'Retry recheck'
                      : 'Recheck after change',
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'RSSI measures received signal here. It cannot identify interference, ISP trouble or router failure. Channel overlap is a local estimate, not measured noise or speed. One recheck does not prove a lasting improvement; repeat under similar conditions. Router support and allowed channels must be verified separately.',
            ),
          ],
        ),
      ),
    );
  }
}

class GuidanceEvidenceCard extends StatelessWidget {
  const GuidanceEvidenceCard({
    super.key,
    required this.title,
    required this.evidence,
  });
  final String title;
  final WifiEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final ap = evidence.ap;
    final local = evidence.at.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('${ap.name} • ${ap.bssid}'),
          Text('${ap.rssi} dBm • ${ap.quality} signal'),
          Text('${ap.band.label} • channel ${ap.channel} • ${ap.width} MHz'),
          Text(
            'Relative overlap estimate: ${evidence.overlap.toStringAsFixed(2)}',
          ),
          Text('Observed at $time • single live observation'),
        ],
      ),
    );
  }
}
