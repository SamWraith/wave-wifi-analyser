import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_motion.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/theme_reveal.dart';
import '../widgets/stable_text_slot.dart';
import '../widgets/scan_activity.dart';
import 'analyser_providers.dart';

const pages = ['Overview', 'Spectrum', 'Networks', 'Channels', 'Settings'];
const pageIcons = [
  Icons.dashboard_outlined,
  Icons.stacked_line_chart_rounded,
  Icons.wifi_rounded,
  Icons.tune_rounded,
  Icons.settings_outlined,
];

class AnalyserSidebar extends StatelessWidget {
  const AnalyserSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SidebarBrand(),
              const SizedBox(height: 44),
              _SidebarDestinations(selected: selected, onSelected: onSelected),
              const Spacer(),
              const _PrivacyCard(),
              const SizedBox(height: 18),
              const _WorkspaceIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.wifi_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'wave',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Your network, in focus.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _SidebarDestinations extends StatelessWidget {
  const _SidebarDestinations({
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'WORKSPACE',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: 14),
      ...List.generate(
        pages.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WaveInteractive(
            onTap: () => onSelected(i),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selected: selected == i,
              selectedTileColor: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .12),
              leading: Icon(pageIcons[i], size: 21),
              title: Text(
                pages[i],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => WavePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 24),
        const SizedBox(height: 12),
        const Text(
          'Local by design',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Network scans stay on your device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _WorkspaceIndicator extends ConsumerWidget {
  const _WorkspaceIndicator();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(analyserProvider.select((state) => state.demo));
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 7,
          color: demo ? const Color(0xFFEBA85F) : const Color(0xFF2CC9A8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            demo ? 'Demo workspace' : 'Android workspace',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class AnalyserHeader extends ConsumerWidget {
  const AnalyserHeader({super.key, required this.selected, required this.wide});
  final int selected;
  final bool wide;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (busy, paused) = ref.watch(
      analyserProvider.select((s) => (s.busy, s.paused)),
    );
    final c = ref.read(analyserProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NETWORK INTELLIGENCE',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pages[selected] == 'Overview'
                    ? 'Know your WiFi.'
                    : pages[selected],
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(switch (selected) {
                0 => 'A clearer picture of the air around you.',
                1 => 'See where nearby networks overlap.',
                2 => 'Every access point. Every detail.',
                3 => 'Find breathing room for your network.',
                _ => 'Make Wave feel like yours.',
              }, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Builder(
          builder: (buttonContext) => IconButton(
            tooltip: 'Switch light / dark theme',
            onPressed: () => ThemeReveal.change(buttonContext, () {
              c.setTheme(
                Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            }),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ),
        if (wide) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: busy || paused
                ? null
                : () {
                    WaveHaptics.impact();
                    c.scan();
                  },
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
            label: const Text('Scan networks'),
          ),
        ],
      ],
    );
  }
}

class ScanStatusBar extends ConsumerWidget {
  const ScanStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (demo, paused, busy, status) = ref.watch(
      analyserProvider.select((s) => (s.demo, s.paused, s.busy, s.status)),
    );
    final c = ref.read(analyserProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            (demo
                    ? const Color(0xFFEBA85F)
                    : Theme.of(context).colorScheme.primary)
                .withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const ScanActivity(),
          const SizedBox(width: 10),
          Expanded(
            child: StableTextSlot(
              text: paused ? 'Scanning paused. Last results retained.' : status,
              alternatives: const [
                'Scanning… Cached results shown until new scan arrives.',
                'Allow precise location to discover nearby WiFi networks.',
                'Enable Location services in Android settings to scan WiFi.',
                'WiFi scans temporarily unavailable. Showing cached results.',
                'Scanning paused. Last results retained.',
              ],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: paused ? 'Resume scanning' : 'Pause scanning',
            onPressed: () {
              WaveHaptics.selection();
              c.togglePause();
            },
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 18,
            ),
          ),
          IconButton(
            tooltip: 'Scan now',
            onPressed: busy || paused
                ? null
                : () {
                    WaveHaptics.impact();
                    c.scan();
                  },
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class BandSelector extends ConsumerWidget {
  const BandSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBand = ref.watch(analyserProvider.select((s) => s.band));
    final count = ref.watch(
      bandPointsProvider.select((points) => points.length),
    );
    final c = ref.read(analyserProvider.notifier);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...WifiBand.values.map(
          (band) => ChoiceChip(
            label: Text(band.label),
            selected: selectedBand == band,
            onSelected: (_) {
              if (band != selectedBand) {
                WaveHaptics.selection();
                c.setBand(band);
              }
            },
            showCheckmark: false,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count access points',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
