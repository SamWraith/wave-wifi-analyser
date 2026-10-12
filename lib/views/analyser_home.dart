import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/analyser_state.dart';
import '../viewmodels/analyser_view_model.dart';
import '../widgets/signal_charts.dart';

const pages = ['Overview', 'Spectrum', 'Networks', 'Channels', 'Settings'];
const pageIcons = [
  Icons.dashboard_outlined,
  Icons.stacked_line_chart_rounded,
  Icons.wifi_rounded,
  Icons.tune_rounded,
  Icons.settings_outlined,
];

class AnalyserHome extends ConsumerStatefulWidget {
  const AnalyserHome({super.key});
  @override
  ConsumerState<AnalyserHome> createState() => _AnalyserHomeState();
}

class _AnalyserHomeState extends ConsumerState<AnalyserHome> {
  int selected = 0;
  bool timeGraph = false;
  AnalyserViewModel get c => ref.read(analyserProvider.notifier);
  AnalyserState get s => ref.read(analyserProvider);
  @override
  Widget build(BuildContext context) {
    ref.watch(analyserProvider);
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 32 : 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _header(wide),
                              const SizedBox(height: 22),
                              _statusBar(),
                              const SizedBox(height: 26),
                              if (selected != 4) ...[
                                _bandSelector(),
                                const SizedBox(height: 24),
                              ],
                              switch (selected) {
                                0 => _overview(),
                                1 => _spectrum(),
                                2 => _networks(),
                                3 => _channels(),
                                _ => _settings(),
                              },
                              const SizedBox(height: 24),
                              Text(
                                'WAVE  /  WIFI, MADE VISIBLE',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!wide)
                    NavigationBar(
                      selectedIndex: selected,
                      onDestinationSelected: (v) =>
                          setState(() => selected = v),
                      destinations: List.generate(
                        pages.length,
                        (i) => NavigationDestination(
                          icon: Icon(pageIcons[i]),
                          label: pages[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Container(
      width: 230,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.wifi_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'wave',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your network, in focus.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 44),
            Text(
              'WORKSPACE',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(
              pages.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: selected == i,
                  selectedTileColor: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .12),
                  leading: Icon(pageIcons[i], size: 21),
                  title: Text(
                    pages[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => setState(() => selected = i),
                ),
              ),
            ),
            const Spacer(),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 24),
                  const SizedBox(height: 12),
                  const Text(
                    'Local by design',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Network scans stay on your device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: s.demo
                      ? const Color(0xFFEBA85F)
                      : const Color(0xFF2CC9A8),
                ),
                const SizedBox(width: 8),
                Text(
                  s.demo ? 'Demo workspace' : 'Android workspace',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _header(bool wide) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NETWORK INTELLIGENCE',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pages[selected] == 'Overview'
                  ? 'Know your WiFi.'
                  : pages[selected],
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 6),
            Text(switch (selected) {
              0 => 'A clearer picture of the air around you.',
              1 => 'See where nearby networks overlap.',
              2 => 'Every access point. Every detail.',
              3 => 'Find breathing room for your network.',
              _ => 'Make Wave feel like yours.',
            }, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Switch light / dark theme',
        onPressed: () => c.setTheme(
          Theme.of(context).brightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
        icon: Icon(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
      ),
      if (wide) ...[
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: s.busy || s.paused ? null : () => c.scan(),
          icon: s.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 19),
          label: const Text('Scan networks'),
        ),
      ],
    ],
  );
  Widget _statusBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color:
          (s.demo
                  ? const Color(0xFFEBA85F)
                  : Theme.of(context).colorScheme.primary)
              .withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          s.demo ? Icons.science_outlined : Icons.sensors_rounded,
          size: 18,
          color: s.demo
              ? const Color(0xFFCA914C)
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            s.paused ? 'Scanning paused. Last results retained.' : s.status,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: s.paused ? 'Resume scanning' : 'Pause scanning',
          onPressed: c.togglePause,
          icon: Icon(
            s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 18,
          ),
        ),
        IconButton(
          tooltip: 'Scan now',
          onPressed: s.busy || s.paused ? null : () => c.scan(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
    ),
  );
  Widget _bandSelector() => Wrap(
    spacing: 10,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ...WifiBand.values.map(
        (band) => ChoiceChip(
          label: Text(band.label),
          selected: s.band == band,
          onSelected: (_) => c.setBand(band),
          showCheckmark: false,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '${s.bandPoints.length} access points',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
  Widget _panel({required Widget child, EdgeInsets? padding}) => Card(
    child: Padding(padding: padding ?? const EdgeInsets.all(22), child: child),
  );
  Widget _heading(String title, String subtitle, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ?trailing,
    ],
  );
  Widget _overview() {
    final ap = s.connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            final narrow = bounds.maxWidth < 680;
            final cards = [
              _connection(ap),
              Column(
                children: [
                  _metric(
                    'NEARBY NETWORKS',
                    '${s.bandPoints.length}',
                    'On ${s.band.label}',
                    Icons.radar_rounded,
                  ),
                  const SizedBox(height: 14),
                  _metric(
                    'CLEAREST CANDIDATE',
                    s.bandPoints.isEmpty
                        ? '—'
                        : 'CH ${s.ratings.first.channel}',
                    'Relative overlap estimate',
                    Icons.auto_awesome_outlined,
                  ),
                ],
              ),
            ];
            return narrow
                ? Column(
                    children: [cards[0], const SizedBox(height: 14), cards[1]],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: cards[0]),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: cards[1]),
                    ],
                  );
          },
        ),
        const SizedBox(height: 22),
        _chartPanel(),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, bounds) {
            final cards = [
              _insights(ap),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      'Nearby networks',
                      'Strongest signals in this band',
                      trailing: TextButton(
                        onPressed: () => setState(() => selected = 2),
                        child: const Text('View all'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (s.visiblePoints.isEmpty)
                      _empty('No networks in this band'),
                    ...s.visiblePoints.take(3).map(_networkRow),
                  ],
                ),
              ),
            ];
            return bounds.maxWidth < 760
                ? Column(
                    children: [cards[0], const SizedBox(height: 18), cards[1]],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 18),
                      Expanded(child: cards[1]),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _connection(AccessPoint? ap) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7965DB), Color(0xFF4D469D)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.demo
                    ? 'SIMULATED CONNECTION'
                    : ap != null
                    ? 'CONNECTED NETWORK'
                    : 'CONNECTION',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (ap != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ap.quality,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          ap?.name ?? 'Find your network',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          ap == null
              ? 'Scan on Android to read nearby access points.'
              : '${ap.band.label}  ·  ${ap.security}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 32,
          runSpacing: 16,
          children: [
            _heroStat(ap != null ? '${ap.rssi}' : '—', 'dBm • signal'),
            _heroStat(ap != null ? '${ap.channel}' : '—', 'channel'),
            _heroStat(ap != null ? '${ap.width}' : '—', 'MHz • width'),
          ],
        ),
      ],
    ),
  );
  Widget _heroStat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
  Widget _metric(String label, String value, String note, IconData icon) =>
      _panel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 9, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    note,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  Widget _chartPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          timeGraph ? 'Signal over time' : 'Channel landscape',
          timeGraph
              ? 'Fresh scan samples only • up to 60 per access point'
              : 'Signal strength across ${s.band.label}',
          trailing: IconButton(
            tooltip: timeGraph ? 'Show channel graph' : 'Show signal history',
            onPressed: () => setState(() => timeGraph = !timeGraph),
            icon: Icon(
              timeGraph ? Icons.stacked_line_chart : Icons.timeline_rounded,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (s.visiblePoints.isEmpty)
          _empty(
            'No scan results yet. Scan nearby networks or enable demo in Settings.',
          )
        else ...[
          SignalChart(
            points: s.visiblePoints,
            band: s.band,
            history: s.history,
            time: timeGraph,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: s.visiblePoints
                .take(8)
                .map(
                  (ap) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: pointColor(ap),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ap.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          if (timeGraph && s.history.isEmpty)
            Text(
              'History begins with the next fresh scan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    ),
  );
  Widget _spectrum() => Column(
    children: [
      _chartPanel(),
      const SizedBox(height: 18),
      _panel(
        child: Text(
          'Chart envelopes illustrate reported center frequency and channel width. Signal strength is measured at this device; overlap does not measure internet speed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
  Widget _insights(AccessPoint? ap) {
    final open = s.bandPoints
        .where((a) => a.security == 'Open' || a.security == 'WEP')
        .length;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Network insights',
            'Local rules. Clear next steps.',
            trailing: Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 20),
          _insight(
            Icons.signal_cellular_alt_rounded,
            ap == null ? 'No connected AP identified' : '${ap.quality} signal',
            ap == null
                ? 'Scan on Android while connected to WiFi.'
                : ap.rssi < -70
                ? 'Move closer to your access point and compare signal history.'
                : 'Signal looks healthy at your current location.',
          ),
          const SizedBox(height: 18),
          _insight(
            Icons.layers_outlined,
            'Channel planning',
            s.bandPoints.isEmpty
                ? 'Run a scan before comparing channels.'
                : 'Channel ${s.ratings.first.channel} has lowest estimated overlap among shown candidates. Verify your router supports it.',
          ),
          const SizedBox(height: 18),
          _insight(
            Icons.shield_outlined,
            open > 0 ? '$open open or legacy networks' : 'Security check',
            open > 0
                ? 'Open and WEP networks deserve caution. Prefer WPA2 or WPA3.'
                : 'Use WPA2 or WPA3 on your router. This checks advertised security only.',
          ),
        ],
      ),
    );
  }

  Widget _insight(IconData icon, String title, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.wifi_find_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
  Widget _networks() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Access points',
          'Sorted by signal strength • tap for details',
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: c.setQuery,
          decoration: const InputDecoration(
            hintText: 'Search networks',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (s.visiblePoints.isEmpty) _empty('No matching networks'),
        ...s.visiblePoints.map(_networkRow),
      ],
    ),
  );
  Widget _networkRow(AccessPoint ap) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => _details(ap),
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
  Future<void> _details(AccessPoint ap) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
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
    ),
  );
  Widget _channels() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Channel recommendations',
          'Lower estimated overlap means more room.',
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
          value: s.excludeConnected,
          onChanged: c.setExclude,
        ),
        const SizedBox(height: 16),
        if (s.bandPoints.isEmpty)
          _empty('Scan this band before comparing channels.')
        else
          ...s.ratings.map((r) {
            final max = s.ratings
                .map((v) => v.interference)
                .fold<double>(0, (a, b) => a > b ? a : b);
            final amount = max == 0 ? 0.0 : r.interference / max;
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      'CH ${r.channel}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
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
          }),
        const SizedBox(height: 12),
        Text(
          'Heuristic based on bandwidth overlap and received power, not measured noise or throughput. Candidate list is not a regulatory availability list: router, region, DFS and device support still apply.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  Widget _settings() => Column(
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Appearance', 'A comfortable view, day or night.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: ThemeMode.values
                  .map(
                    (mode) => ChoiceChip(
                      label: Text(switch (mode) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                      selected: s.themeMode == mode,
                      onSelected: (_) => c.setTheme(mode),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              'Scanning',
              'Android scans respect operating system limits.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Demo mode', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Simulated networks for exploring the interface',
                style: TextStyle(fontSize: 12),
              ),
              value: s.demo,
              onChanged: c.setDemo,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Automatic scanning',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                s.demo
                    ? 'Demo updates every 3 seconds'
                    : 'Request every 35 seconds while foregrounded',
                style: const TextStyle(fontSize: 12),
              ),
              value: !s.paused,
              onChanged: (_) => c.togglePause(),
            ),
            const SizedBox(height: 14),
            Text(
              'Minimum signal: ${s.minimumRssi} dBm',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: s.minimumRssi.toDouble(),
              min: -95,
              max: -40,
              divisions: 11,
              label: '${s.minimumRssi} dBm',
              onChanged: (v) => c.setMinimum(v.round()),
            ),
            Text(
              'Filters display only. Channel scoring still includes all scanned access points.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: c.openSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Open Android WiFi settings'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Built for clarity', 'wave • version 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'Android supports live nearby-network scans. iOS, macOS and web currently support demo mode. Precise location permission and Location services are required by Android WiFi scanning APIs. No location coordinates are collected.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Next: device discovery, speed tests, aliases and widgets. These tools are not included in this first build.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}
