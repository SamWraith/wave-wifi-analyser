import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/wifi_data_source.dart';
import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_motion.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/theme_reveal.dart';
import '../widgets/stable_text_slot.dart';
import '../widgets/scan_activity.dart';
import '../widgets/scan_freshness.dart';
import '../repositories/wifi_repository.dart';
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
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SidebarBrand(),
                        const SizedBox(height: 44),
                        _SidebarDestinations(
                          selected: selected,
                          onSelected: onSelected,
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrivacyCard(),
                          SizedBox(height: 18),
                          _WorkspaceIndicator(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact desktop navigation keeps charts useful in medium-width windows.
class AnalyserRail extends StatelessWidget {
  const AnalyserRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bounds.maxHeight),
        child: IntrinsicHeight(
          child: NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: onSelected,
            labelType: NavigationRailLabelType.selected,
            destinations: [
              for (var i = 0; i < pages.length; i++)
                NavigationRailDestination(
                  icon: Tooltip(
                    message: '${pages[i]} · ⌘${i + 1} / Ctrl+${i + 1}',
                    child: Icon(pageIcons[i]),
                  ),
                  label: Text(pages[i]),
                ),
            ],
          ),
        ),
      ),
    ),
  );
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
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'wave',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
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
    final source = ref.watch(analyserProvider.select((state) => state.source));
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 7,
          color: source == WifiDataSource.demo
              ? const Color(0xFFEBA85F)
              : const Color(0xFF2CC9A8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${source.label} workspace',
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
    final (
      source,
      paused,
      busy,
      status,
      cached,
      updated,
      permission,
      location,
      wifi,
      interfaceAvailable,
      redactedCount,
    ) = ref.watch(
      analyserProvider.select(
        (s) => (
          s.source,
          s.paused,
          s.busy,
          s.status,
          s.cached,
          s.lastUpdated,
          s.permission,
          s.locationEnabled,
          s.wifiEnabled,
          s.interfaceAvailable,
          s.redactedCount,
        ),
      ),
    );
    final c = ref.read(analyserProvider.notifier);
    final demo = source == WifiDataSource.demo;
    final macos = source == WifiDataSource.macos;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              final expanded =
                  bounds.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(12) > 16;
              final message = paused
                  ? 'Scanning paused. Last results retained.'
                  : busy
                  ? macos
                        ? 'Request pending. Waiting for macOS scan completion.'
                        : 'Request pending. Waiting for Android results.'
                  : status;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (expanded)
                    Text(message, style: Theme.of(context).textTheme.bodySmall)
                  else
                    StableTextSlot(
                      text: message,
                      alternatives: const [
                        'Scanning… Cached results shown until new scan arrives.',
                        'Allow precise location to discover nearby WiFi networks.',
                        'Enable Location services in Android settings to scan WiFi.',
                        'WiFi scans temporarily unavailable. Showing cached results.',
                        'Scanning paused. Last results retained.',
                        'Request pending. Waiting for macOS scan completion.',
                        'Allow location access in macOS settings to identify nearby networks.',
                      ],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ScanFreshness(
                    updated: updated,
                    demo: demo,
                    cached: cached,
                    source: source,
                  ),
                ],
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              );
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: expanded
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      const ScanActivity(),
                      const SizedBox(width: 10),
                      Expanded(child: summary),
                      if (!expanded) controls,
                    ],
                  ),
                  if (expanded)
                    Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            },
          ),
          if (!demo &&
              !paused &&
              !busy &&
              (!permission || !location || !wifi || redactedCount > 0))
            Wrap(
              spacing: 8,
              children: [
                if (!permission) ...[
                  TextButton(
                    onPressed: () {
                      WaveHaptics.selection();
                      c.scan();
                    },
                    child: Text(
                      macos ? 'Allow location' : 'Allow precise location',
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        c.openSettings(target: WifiSettingsTarget.permission),
                    child: Text(
                      macos ? 'Location privacy settings' : 'App permissions',
                    ),
                  ),
                ] else if (!location)
                  TextButton(
                    onPressed: () =>
                        c.openSettings(target: WifiSettingsTarget.location),
                    child: const Text('Enable Location'),
                  )
                else if (macos && !interfaceAvailable)
                  const Text(
                    'WiFi interface unavailable. Connect supported WiFi hardware, then scan again.',
                  )
                else if (redactedCount > 0)
                  TextButton(
                    onPressed: () =>
                        c.openSettings(target: WifiSettingsTarget.permission),
                    child: const Text('Review Location access'),
                  )
                else if (!wifi)
                  TextButton(
                    onPressed: c.openSettings,
                    child: const Text('Enable WiFi'),
                  ),
              ],
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
