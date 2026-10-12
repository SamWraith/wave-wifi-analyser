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
  });

  final AccessPoint point;
  final bool visible, solo;
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
      label: Text(
        point.name,
        style: TextStyle(
          decoration: visible ? null : TextDecoration.lineThrough,
        ),
      ),
      onSelected: (_) => onTap(),
    ),
  );
}
