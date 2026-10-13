import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
import '../models/ap_preference.dart';
import '../models/access_point.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import '../widgets/access_point_preferences.dart';
import '../widgets/wave_motion.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/network_tile.dart';
import '../widgets/wave_components.dart';
import 'analyser_providers.dart';

class NetworksPage extends ConsumerStatefulWidget {
  const NetworksPage({super.key});
  @override
  ConsumerState<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends ConsumerState<NetworksPage> {
  late final TextEditingController _query;
  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: ref.read(analyserProvider).query);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(analyserProvider.select((state) => state.query), (
      previous,
      next,
    ) {
      if (_query.text != next) {
        _query.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    final points = ref.watch(visiblePointsProvider);
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Access points',
            subtitle: 'Sorted by signal strength • tap for details',
          ),
          const ApPreferencesStatus(),
          const _SavedPointsSection(),
          const SizedBox(height: 20),
          TextField(
            controller: _query,
            onChanged: ref.read(analyserProvider.notifier).setQuery,
            decoration: const InputDecoration(
              hintText: 'Search SSIDs or local aliases',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (points.isEmpty) const EmptyState(text: 'No matching networks'),
          ...points.map((ap) => NetworkTile(key: ValueKey(ap.bssid), ap: ap)),
        ],
      ),
    );
  }
}

class _SavedPointsSection extends ConsumerWidget {
  const _SavedPointsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(apPreferencesProvider.select((s) => s.entries));
    final sorted = entries.values.toList()
      ..sort((a, b) {
        final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return nameOrder == 0 ? a.bssid.compareTo(b.bssid) : nameOrder;
      });
    if (sorted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Tap an access point to save a favorite or local alias.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final observed = {
      for (final ap in ref.watch(accessPointsProvider))
        preferenceKey(ap.bssid): ap,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SavedPointsGroup(
          title: 'Favorites',
          entries: sorted.where((entry) => entry.favorite).toList(),
          observed: observed,
        ),
        _SavedPointsGroup(
          title: 'Saved aliases',
          entries: sorted
              .where((entry) => !entry.favorite && entry.alias != null)
              .toList(),
          observed: observed,
        ),
      ],
    );
  }
}

class _SavedPointsGroup extends StatelessWidget {
  const _SavedPointsGroup({
    required this.title,
    required this.entries,
    required this.observed,
  });
  final String title;
  final List<ApPreference> entries;
  final Map<String, AccessPoint> observed;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SectionHeading(
          title: title,
          subtitle: 'All bands • independent of search and signal filters',
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          if (observed[preferenceKey(entry.bssid)] case final ap?)
            NetworkTile(key: ValueKey('saved-${entry.bssid}'), ap: ap)
          else
            _MissingFavoriteTile(
              key: ValueKey('saved-${entry.bssid}'),
              entry: entry,
            ),
        const Divider(height: 24),
      ],
    );
  }
}

class _MissingFavoriteTile extends StatelessWidget {
  const _MissingFavoriteTile({super.key, required this.entry});
  final ApPreference entry;

  @override
  Widget build(BuildContext context) => WaveInteractive(
    borderRadius: BorderRadius.circular(12),
    onTap: () {
      WaveHaptics.impact();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: WaveMotion.sheetStyle(context),
        builder: (context) => _SavedAccessPointSheet(entry: entry),
      );
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        children: [
          Icon(
            entry.favorite ? Icons.star_rounded : Icons.label_outline_rounded,
            semanticLabel: entry.favorite ? 'Favorite' : 'Local alias',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (entry.alias != null)
                  Text(
                    'SSID: ${entry.ssid.isEmpty ? 'Hidden network' : entry.ssid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  'Not seen · ${entry.bssid}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _SavedAccessPointSheet extends ConsumerWidget {
  const _SavedAccessPointSheet({required this.entry});
  final ApPreference entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(
          apPreferencesProvider.select(
            (s) => s.entries[preferenceKey(entry.bssid)],
          ),
        ) ??
        ApPreference(bssid: entry.bssid, ssid: entry.ssid);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.name, style: Theme.of(context).textTheme.titleLarge),
            if (current.alias != null)
              Text(
                'SSID: ${current.ssid.isEmpty ? 'Hidden network' : current.ssid}',
              ),
            const SizedBox(height: 8),
            Text(current.bssid),
            const SizedBox(height: 8),
            const Text(
              'Not seen in current results. No current signal or channel measurement is available.',
            ),
            const SizedBox(height: 20),
            AccessPointPreferences(saved: current),
          ],
        ),
      ),
    );
  }
}
