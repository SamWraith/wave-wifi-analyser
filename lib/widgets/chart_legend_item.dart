import 'package:flutter/material.dart';

import '../models/access_point.dart';
import 'signal_charts.dart';

/// Accessible legend control; identity/color follow BSSID rather than SSID/order.
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({
    super.key,
    required this.point,
    required this.visible,
    required this.solo,
    required this.nextAction,
    required this.onTap,
    this.compact = false,
  });

  final AccessPoint point;
  final bool visible, solo, compact;
  final String nextAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${point.name} · ${point.bssid}\n$nextAction',
    child: FilterChip(
      key: ValueKey('chart-legend-${point.bssid}'),
      selected: visible,
      showCheckmark: false,
      selectedColor: pointColor(point).withValues(alpha: .15),
      avatar: Icon(
        solo
            ? Icons.radio_button_checked_rounded
            : visible
            ? Icons.circle
            : Icons.remove_circle_outline_rounded,
        size: visible && !solo ? 10 : 18,
        color: pointColor(point),
      ),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 140 : double.infinity),
        child: Text(
          point.name,
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style:
              (compact
                      ? Theme.of(context).textTheme.labelMedium
                      : const TextStyle())
                  ?.copyWith(
                    decoration: visible
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
        ),
      ),
      onSelected: (_) => onTap(),
    ),
  );
}
