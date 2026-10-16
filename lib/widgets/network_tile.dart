import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ap_preference.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import 'access_point_preferences.dart';

import '../models/access_point.dart';
import 'signal_charts.dart';
import 'wave_motion.dart';
import 'wave_haptics.dart';
import 'access_point_detail_row.dart';

class NetworkTile extends ConsumerWidget {
  const NetworkTile({super.key, required this.ap});
  final AccessPoint ap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(
      apPreferencesProvider.select((s) => s.entries[preferenceKey(ap.bssid)]),
    );
    return WaveInteractive(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showAccessPointDetails(context, ap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final stacked =
                bounds.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(13) > 18;
            final metadata = Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'CH ${ap.channel} · ${ap.security} · ${ap.widthLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  ap.bssid,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pointColor(ap).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        ap.connected || ap.security == 'Open'
                            ? Icons.wifi_rounded
                            : Icons.wifi_lock_rounded,
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
                            preference?.alias ?? ap.name,
                            maxLines: stacked ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (preference?.alias != null)
                            Text(
                              ap.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (!stacked) ...[
                            const SizedBox(height: 4),
                            metadata,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        WaveValue(
                          '${ap.rssi}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'dBm',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (preference?.favorite == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          semanticLabel: 'Favorite',
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (stacked) ...[const SizedBox(height: 8), metadata],
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> showAccessPointDetails(BuildContext context, AccessPoint ap) {
  WaveHaptics.impact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: WaveMotion.sheetStyle(context),
    builder: (context) => AccessPointDetailsSheet(ap: ap),
  );
}

class AccessPointDetailsSheet extends ConsumerWidget {
  const AccessPointDetailsSheet({super.key, required this.ap});
  final AccessPoint ap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(
      apPreferencesProvider.select((s) => s.entries[preferenceKey(ap.bssid)]),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    preference?.alias ?? ap.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close access point details',
                  onPressed: () {
                    WaveHaptics.selection();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (preference?.alias != null)
              Text(
                'SSID: ${ap.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 5),
            Text(
              ap.connected ? 'Connected access point' : 'Nearby access point',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AccessPointPreferences(ap: ap),
            const SizedBox(height: 24),
            ...{
              'BSSID': ap.bssid,
              'Signal': '${ap.rssi} dBm • ${ap.quality}',
              'Frequency': '${ap.frequency} MHz',
              'Channel': '${ap.channel} (${ap.band.label})',
              'Width': ap.widthLabel,
              'Security': ap.security,
              'Distance estimate': '~${ap.distance.toStringAsFixed(1)} m',
            }.entries.map(
              (e) => AccessPointDetailRow(label: e.key, value: e.value),
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
}
