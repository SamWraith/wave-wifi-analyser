import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/analyser_view_model.dart';
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
          const SizedBox(height: 20),
          TextField(
            controller: _query,
            onChanged: ref.read(analyserProvider.notifier).setQuery,
            decoration: const InputDecoration(
              hintText: 'Search networks',
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
