import 'package:flutter/material.dart';

import '../models/channel_plan.dart';
import 'channel_plan_tile.dart';
import 'wave_haptics.dart';

/// Bounded presentation batch within the shell's existing page scroll.
class ChannelPlanList extends StatefulWidget {
  const ChannelPlanList({super.key, required this.plans});
  final List<ChannelPlan> plans;
  @override
  State<ChannelPlanList> createState() => _ChannelPlanListState();
}

class _ChannelPlanListState extends State<ChannelPlanList> {
  static const _batch = 8;
  int _page = 0;

  @override
  void didUpdateWidget(ChannelPlanList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep page through fresh scans; assumption changes get a new widget key.
    final lastPage = (widget.plans.length - 1) ~/ _batch;
    if (_page > lastPage) _page = lastPage < 0 ? 0 : lastPage;
  }

  void _changePage(int page) {
    WaveHaptics.selection();
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final start = _page * _batch;
    final end = (start + _batch).clamp(0, widget.plans.length);
    final max = widget.plans.fold<double>(
      0,
      (value, plan) => plan.score > value ? plan.score : value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Candidates ${start + 1}–$end of ${widget.plans.length} • lowest overlap first',
        ),
        if (widget.plans.length > _batch)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _page == 0 ? null : () => _changePage(_page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous candidates'),
              ),
              OutlinedButton.icon(
                onPressed: end == widget.plans.length
                    ? null
                    : () => _changePage(_page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next candidates'),
              ),
            ],
          ),
        for (final plan in widget.plans.sublist(start, end))
          ChannelPlanTile(
            key: ValueKey('${plan.channel}:${plan.center}:${plan.width}'),
            plan: plan,
            amount: max == 0 ? 0 : plan.score / max,
          ),
      ],
    );
  }
}
