import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      PreferencesErrorCard(),
      AppearanceCard(),
      SizedBox(height: 18),
      ScanningSettingsCard(),
      SizedBox(height: 18),
      AboutCard(),
    ],
  );
}

class PreferencesErrorCard extends ConsumerWidget {
  const PreferencesErrorCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(
      analyserProvider.select((state) => state.preferencesError),
    );
    return error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: WavePanel(
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(error)),
                ],
              ),
            ),
          );
  }
}

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeSelected = ref.watch(
      analyserProvider.select((state) => state.themeMode),
    );
    final c = ref.read(analyserProvider.notifier);
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Appearance',
            subtitle: 'A comfortable view, day or night.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: ThemeMode.values
                .map(
                  (mode) => ChoiceChip(
                    label: Text(switch (mode) {
                      ThemeMode.system => 'System',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    }),
                    selected: modeSelected == mode,
                    onSelected: (_) => c.setTheme(mode),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class ScanningSettingsCard extends ConsumerWidget {
  const ScanningSettingsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (demo, paused, minimum) = ref.watch(
      analyserProvider.select(
        (state) => (state.demo, state.paused, state.minimumRssi),
      ),
    );
    final c = ref.read(analyserProvider.notifier);
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Scanning',
            subtitle: 'Android scans respect operating system limits.',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Demo mode', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Simulated networks for exploring the interface',
              style: TextStyle(fontSize: 12),
            ),
            value: demo,
            onChanged: c.setDemo,
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Automatic scanning',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              demo
                  ? 'Demo updates every 3 seconds'
                  : 'Request every 35 seconds while foregrounded',
              style: const TextStyle(fontSize: 12),
            ),
            value: !paused,
            onChanged: (_) => c.togglePause(),
          ),
          const SizedBox(height: 14),
          Text(
            'Minimum signal: $minimum dBm',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: minimum.toDouble(),
            min: -95,
            max: -40,
            divisions: 11,
            label: '$minimum dBm',
            onChanged: (v) => c.updateMinimum(v.round()),
            onChangeEnd: (v) => c.setMinimum(v.round()),
          ),
          Text(
            'Filters display only. Channel scoring still includes all scanned access points.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: c.openSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open Android WiFi settings'),
          ),
        ],
      ),
    );
  }
}

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});
  @override
  Widget build(BuildContext context) => WavePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: 'Built for clarity',
          subtitle: 'wave • version 1.0.0',
        ),
        const SizedBox(height: 16),
        Text(
          'Android supports live nearby-network scans. iOS, macOS and web currently support demo mode. Precise location permission and Location services are required by Android WiFi scanning APIs. No location coordinates are collected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Next: device discovery, speed tests, aliases and widgets. These tools are not included in this first build.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
