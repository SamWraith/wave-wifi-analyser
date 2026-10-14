import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/channel_plan.dart';
import '../viewmodels/channel_planning_view_model.dart';
import 'wave_haptics.dart';
import 'wave_motion.dart';

class ChannelPlanningControls extends ConsumerWidget {
  const ChannelPlanningControls({
    super.key,
    required this.band,
    required this.assumptions,
  });
  final WifiBand band;
  final PlanningAssumptions assumptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${band.label} • ${assumptions.width} MHz desired width'),
      const SizedBox(height: 4),
      Text(
        assumptions.channels.isEmpty
            ? 'Example primary channels: ${defaultPlanningChannels(band, assumptions.width).join(', ')}'
            : 'Your primary-channel shortlist: ${assumptions.channels.join(', ')}',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Change assumptions'),
            onPressed: () async {
              WaveHaptics.selection();
              final edit = await showDialog<PlanningAssumptions>(
                context: context,
                animationStyle: WaveMotion.sheetStyle(context),
                builder: (_) => PlanningAssumptionsDialog(
                  band: band,
                  assumptions: assumptions,
                ),
              );
              if (edit == null || !context.mounted) return;
              ref
                  .read(planningAssumptionsProvider.notifier)
                  .apply(band, edit.width, edit.channels.join(', '));
              WaveHaptics.selection();
            },
          ),
          TextButton(
            onPressed: () {
              ref.read(planningAssumptionsProvider.notifier).reset(band);
              WaveHaptics.selection();
            },
            child: const Text('Reset this band'),
          ),
        ],
      ),
      Text(
        'Session only. Shortlist is your input, not proof of router or regional support.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class PlanningAssumptionsDialog extends StatefulWidget {
  const PlanningAssumptionsDialog({
    super.key,
    required this.band,
    required this.assumptions,
  });
  final WifiBand band;
  final PlanningAssumptions assumptions;
  @override
  State<PlanningAssumptionsDialog> createState() =>
      _PlanningAssumptionsDialogState();
}

class _PlanningAssumptionsDialogState extends State<PlanningAssumptionsDialog> {
  late final TextEditingController _channels;
  late int _width;
  String? _error;

  @override
  void initState() {
    super.initState();
    _channels = TextEditingController(
      text: widget.assumptions.channels.join(', '),
    );
    _width = widget.assumptions.width;
  }

  @override
  void dispose() {
    _channels.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      final channels = parsePlanningChannels(
        _channels.text,
        widget.band,
        _width,
      );
      Navigator.of(context)
          .pop(PlanningAssumptions(width: _width, channels: channels));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Plan ${widget.band.label}'),
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Desired width'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final width in planningWidths(widget.band))
                ChoiceChip(
                  label: Text('$width MHz'),
                  selected: width == _width,
                  onSelected: (_) {
                    WaveHaptics.selection();
                    setState(() {
                      _width = width;
                      _error = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Primary channels'),
          const SizedBox(height: 8),
          TextField(
            controller: _channels,
            maxLength: 512,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Channels',
              hintText: defaultPlanningChannels(widget.band, _width).join(', '),
              errorText: _error,
              errorMaxLines: 4,
            ),
          ),
          const Text(
            'Separate with commas or spaces. Blank restores examples; duplicates merge.',
          ),
          TextButton(
            onPressed: () {
              _channels.clear();
              setState(() => _error = null);
              WaveHaptics.selection();
            },
            child: const Text('Clear shortlist'),
          ),
          const Text(
            'Bonded centers are calculated from primary channels. 2.4 GHz 40 MHz shows both extension choices when possible. 320 MHz and 80+80 planning are not supported.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply plan')),
    ],
  );
}
