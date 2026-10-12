import 'package:flutter/material.dart';

import 'wave_haptics.dart';
import 'wave_motion.dart';

/// Overview keeps one scrollable row; expansion reveals the same legend items.
class ChartLegend extends StatefulWidget {
  const ChartLegend({
    super.key,
    required this.items,
    required this.compact,
    required this.onReset,
  });

  final List<Widget> items;
  final bool compact;
  final VoidCallback? onReset;

  @override
  State<ChartLegend> createState() => _ChartLegendState();
}

class _ChartLegendState extends State<ChartLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tap names: hide → include → solo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: widget.onReset,
                child: const Text('Show all'),
              ),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: widget.items),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _expanded
                  ? Text(
                      'WiFi legends',
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  : SingleChildScrollView(
                      key: const PageStorageKey('compact-chart-legend'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final item in widget.items)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: item,
                            ),
                        ],
                      ),
                    ),
            ),
            IconButton(
              tooltip: 'Show all networks',
              onPressed: widget.onReset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            IconButton(
              tooltip: _expanded
                  ? 'Collapse WiFi legends'
                  : 'Expand WiFi legends',
              onPressed: () {
                WaveHaptics.selection();
                setState(() => _expanded = !_expanded);
              },
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ),
          ],
        ),
        if (_expanded)
          WaveReveal(
            child: Wrap(spacing: 8, runSpacing: 8, children: widget.items),
          ),
      ],
    );
  }
}
