import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../models/wifi_data_source.dart';
import '../widgets/wave_components.dart';
import '../widgets/theme_reveal.dart';
import '../widgets/wave_haptics.dart';
import 'onboarding_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const PreferencesErrorCard(),
      ResponsivePair(
        breakpoint:
            880 * (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2),
        spacing: 18,
        first: const Column(
          children: [AppearanceCard(), SizedBox(height: 18), AboutCard()],
        ),
        second: const ScanningSettingsCard(),
      ),
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
                  (mode) => Builder(
                    builder: (chipContext) => ChoiceChip(
                      label: Text(switch (mode) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                      selected: modeSelected == mode,
                      onSelected: (_) {
                        if (mode != modeSelected) {
                          ThemeReveal.change(chipContext, () {
                            c.setTheme(mode);
                          });
                        }
                      },
                    ),
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
    final (source, paused, minimum) = ref.watch(
      analyserProvider.select(
        (state) => (state.source, state.paused, state.minimumRssi),
      ),
    );
    final c = ref.read(analyserProvider.notifier);
    final demo = source == WifiDataSource.demo;
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Scanning',
            subtitle: demo
                ? 'Explicit simulated data for exploring Wave.'
                : '${source.label} scans respect operating system limits.',
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
            onChanged: (value) {
              WaveHaptics.selection();
              c.setDemo(value);
            },
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
            onChanged: (_) {
              WaveHaptics.selection();
              c.togglePause();
            },
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
            onChangeEnd: (v) {
              WaveHaptics.selection();
              c.setMinimum(v.round());
            },
          ),
          Text(
            'Filters display only. Channel scoring still includes all scanned access points.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (source == WifiDataSource.macos) ...[
            const SizedBox(height: 14),
            Text(
              source.observationLimitations,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: c.openSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open WiFi settings'),
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
          'Android and macOS support live nearby-network scans. Other platforms support explicit demo mode. Android requires precise location access and Location services. macOS requires Location access to expose network identifiers. No location coordinates are collected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (context) =>
                  OnboardingPage(onFinished: () => Navigator.of(context).pop()),
            ),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Replay welcome'),
        ),
        const SizedBox(height: 12),
        Text(
          'Saved room comparisons, local aliases, channel planning and private previewed exports keep your WiFi evidence on your device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
