import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../viewmodels/analyser_view_model.dart';
import '../widgets/wave_components.dart';
import 'analyser_providers.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratings = ref.watch(channelRatingsProvider);
    final hasPoints = ref.watch(
      bandPointsProvider.select((points) => points.isNotEmpty),
    );
    final exclude = ref.watch(
      analyserProvider.select((state) => state.excludeConnected),
    );
    final max = ratings.fold<double>(
      0,
      (value, rating) =>
          rating.interference > value ? rating.interference : value,
    );
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Channel recommendations',
            subtitle: 'Lower estimated overlap means more room.',
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Plan for connected network',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Exclude your connected AP from overlap scoring',
              style: TextStyle(fontSize: 12),
            ),
            value: exclude,
            onChanged: ref.read(analyserProvider.notifier).setExclude,
          ),
          const SizedBox(height: 16),
          if (!hasPoints)
            const EmptyState(text: 'Scan this band before comparing channels.')
          else
            ...ratings.map(
              (rating) => ChannelRatingTile(
                key: ValueKey(rating.channel),
                rating: rating,
                amount: max == 0 ? 0 : rating.interference / max,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Heuristic based on bandwidth overlap and received power, not measured noise or throughput. Candidate list is not a regulatory availability list: router, region, DFS and device support still apply.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ChannelRatingTile extends StatelessWidget {
  const ChannelRatingTile({
    super.key,
    required this.rating,
    required this.amount,
  });
  final ChannelRating rating;
  final double amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            'CH ${rating.channel}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: amount,
              minHeight: 9,
              color: amount < .3
                  ? const Color(0xFF2CC9A8)
                  : Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 75,
          child: Text(
            amount == 0
                ? 'Clear'
                : amount < .3
                ? 'Low'
                : amount < .7
                ? 'Moderate'
                : 'High',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
