import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/access_point.dart';
import 'signal_charts.dart';

class NetworkTile extends StatelessWidget {
  const NetworkTile({super.key, required this.ap});
  final AccessPoint ap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => showAccessPointDetails(context, ap),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pointColor(ap).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              ap.connected ? Icons.wifi_rounded : Icons.wifi_lock_rounded,
              color: pointColor(ap),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ap.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CH ${ap.channel}  ·  ${ap.security}  ·  ${ap.width} MHz',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ap.rssi}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'dBm',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}

Future<void> showAccessPointDetails(BuildContext context, AccessPoint ap) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AccessPointDetailsSheet(ap: ap),
    );

class AccessPointDetailsSheet extends StatelessWidget {
  const AccessPointDetailsSheet({super.key, required this.ap});
  final AccessPoint ap;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ap.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            ap.connected ? 'Connected access point' : 'Nearby access point',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ...{
            'BSSID': ap.bssid,
            'Signal': '${ap.rssi} dBm • ${ap.quality}',
            'Frequency': '${ap.frequency} MHz',
            'Channel': '${ap.channel} (${ap.band.label})',
            'Width': '${ap.width} MHz',
            'Security': ap.security,
            'Distance estimate': '~${ap.distance.toStringAsFixed(1)} m',
          }.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  SelectableText(
                    e.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Distance uses a free-space path-loss estimate. Walls, interference, antenna gain and transmit power can make it inaccurate.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ap.bssid));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('MAC address copied')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy MAC address'),
          ),
        ],
      ),
    ),
  );
}
