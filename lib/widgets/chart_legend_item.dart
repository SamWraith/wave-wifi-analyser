import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ap_preference.dart';
import '../viewmodels/ap_preferences_view_model.dart';

import '../models/access_point.dart';
import 'signal_charts.dart';

/// Accessible legend control; identity/color follow BSSID rather than SSID/order.
class ChartLegendItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final alias = ref.watch(
      apPreferencesProvider.select(
        (s) => s.entries[preferenceKey(point.bssid)]?.alias,
      ),
    );
    final name = alias == null ? point.name : '$alias · ${point.name}';
    final shortBssid = point.bssid.length > 8
        ? point.bssid.substring(point.bssid.length - 8)
        : point.bssid;
    return LayoutBuilder(
      builder: (context, bounds) => Tooltip(
        message: '$name · CH ${point.channel} · ${point.bssid}\n$nextAction',
        child: FilterChip(
          key: ValueKey('chart-legend-${point.bssid}'),
          selected: visible,
          showCheckmark: false,
          selectedColor: pointColor(point).withValues(alpha: .15),
          // Keep icon and text in one measured label. Chip avatars reserve
          // height-dependent width, which can clip a multiline label on relayout.
          label: Builder(
            builder: (context) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact
                    ? 140
                    : (bounds.maxWidth - 32).clamp(0, double.infinity),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    child: Icon(
                      solo
                          ? Icons.radio_button_checked_rounded
                          : visible
                          ? Icons.circle
                          : Icons.remove_circle_outline_rounded,
                      size: visible && !solo ? 10 : 18,
                      color: pointColor(point),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style,
                      softWrap: !compact,
                      overflow: compact
                          ? TextOverflow.ellipsis
                          : TextOverflow.clip,
                      child: Text(
                        '$name · CH ${point.channel} · $shortBssid',
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
                  ),
                ],
              ),
            ),
          ),
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
}
