import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ap_preference.dart';
import '../models/access_point.dart';
import '../models/comparison_session.dart';
import '../viewmodels/analyser_view_model.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import '../viewmodels/comparison_sessions_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/wave_motion.dart';
import 'comparison_export_page.dart';

void showComparisonSessions(BuildContext context) {
  WaveHaptics.selection();
  Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => const SessionsPage()));
}

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});
  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage>
    with WidgetsBindingObserver {
  final _label = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _selected = <String>{};
  String? _bssid;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(comparisonSessionsProvider);
    final points = ref.watch(analyserProvider.select((s) => s.accessPoints));
    final (paused, demo) = ref.watch(
      analyserProvider.select((s) => (s.paused, s.demo)),
    );
    final scanFeedback = ref.watch(
      analyserProvider.select(
        (s) => (
          s.status,
          s.permission,
          s.locationEnabled,
          s.wifiEnabled,
          s.busy,
          s.cached,
          s.lastUpdated,
        ),
      ),
    );
    final preferences = ref.watch(
      apPreferencesProvider.select((s) => s.entries),
    );
    final vm = ref.read(comparisonSessionsProvider.notifier);
    final identities = <String, AccessPoint>{};
    for (final ap in points) {
      final key = preferenceKey(ap.bssid);
      final existing = identities[key];
      if (existing == null || ap.timestamp > existing.timestamp) {
        identities[key] = ap;
      }
    }
    final available = identities.values.toList()
      ..sort((a, b) {
        final af = preferences[preferenceKey(a.bssid)]?.favorite == true;
        final bf = preferences[preferenceKey(b.bssid)]?.favorite == true;
        if (af != bf) return af ? -1 : 1;
        return b.rssi.compareTo(a.rssi);
      });
    final chosen = available
        .where((ap) => preferenceKey(ap.bssid) == _bssid)
        .firstOrNull;
    final selected = sessions.sessions
        .where((s) => _selected.contains(s.id))
        .toList();
    final missing = preferences.values.where(
      (p) =>
          p.favorite &&
          !points.any(
            (ap) => preferenceKey(ap.bssid) == preferenceKey(p.bssid),
          ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Room comparisons')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Text(
                'Record one access point in different rooms. Compare fresh signal observations saved on this device.',
              ),
              const SizedBox(height: 16),
              if (sessions.error != null)
                WavePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sessions.error!),
                      TextButton.icon(
                        onPressed: () {
                          WaveHaptics.selection();
                          vm.retry();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry session storage'),
                      ),
                    ],
                  ),
                ),
              if (sessions.loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Loading saved sessions',
                ),
              if (sessions.saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Saving on this device…'),
                ),
              if (sessions.active case final active?)
                WaveReveal(
                  key: ValueKey(active.id),
                  child: RecordingPanel(
                    session: active,
                    onStop: () {
                      WaveHaptics.impact();
                      vm.stop();
                    },
                    onCancel: () async {
                      if (await _confirm(
                            context,
                            'Discard recording?',
                            'This recording will not be saved.',
                            'Discard',
                          ) &&
                          mounted) {
                        WaveHaptics.selection();
                        vm.cancel();
                      }
                    },
                  ),
                )
              else
                WavePanel(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(
                          title: 'Start a room session',
                          subtitle: 'Same SSID can contain different access points. Choose by BSSID.',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            chosen == null ? null : preferenceKey(chosen.bssid),
                          ),
                          initialValue: chosen == null
                              ? null
                              : preferenceKey(chosen.bssid),
                          isExpanded: true,
                          isDense: false,
                          itemHeight: null,
                          decoration: const InputDecoration(
                            labelText: 'Access point',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Choose nearby access point'),
                          items: available.map((ap) {
                            final p = preferences[preferenceKey(ap.bssid)];
                            return DropdownMenuItem(
                              value: preferenceKey(ap.bssid),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p?.favorite == true ? '★ ' : ''}${p?.alias == null ? ap.name : '${p!.alias} (${ap.name})'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(ap.bssid),
                                    Text(
                                      '${ap.band.label} · CH ${ap.channel} · ${ap.width} MHz',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            WaveHaptics.selection();
                            setState(() => _bssid = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _label,
                          decoration: const InputDecoration(
                            labelText: 'Room or session label (optional)',
                            hintText: 'e.g. Study, near desk',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value?.trim().length ?? 0) >
                                  maxSessionLabelLength
                              ? 'Use $maxSessionLabelLength characters or fewer.'
                              : null,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 12),
                        if (missing.isNotEmpty)
                          Text(
                            'Saved favorites not currently seen: ${missing.map((p) => '${p.name} (${p.bssid})').join(', ')}. Scan again before recording them.',
                          ),
                        if (available.isEmpty)
                          const Text(
                            'No access points seen yet. Return to Overview and scan.',
                          ),
                        if (paused || !_foreground)
                          const Text(
                            'Resume foreground scanning before starting.',
                          ),
                        if (demo)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'SIMULATED DEMO · kept separate from measured sessions.',
                            ),
                          ),
                        if (!vm.loaded)
                          const Text(
                            'Saved session storage must load before recording. Retry if loading failed.',
                          ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed:
                              chosen == null ||
                                  paused ||
                                  !_foreground ||
                                  !vm.loaded
                              ? null
                              : () {
                                  if (_form.currentState!.validate() &&
                                      vm.start(
                                        chosen,
                                        _label.text.trim(),
                                        demo: demo,
                                      )) {
                                    WaveHaptics.impact();
                                    FocusScope.of(context).unfocus();
                                    _label.clear();
                                  }
                                },
                          icon: const Icon(Icons.fiber_manual_record_rounded),
                          label: Text(
                            demo
                                ? 'Start simulated session'
                                : 'Start recording',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (sessions.active != null)
                WavePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scanFeedback.$1),
                      if (!demo &&
                          (!scanFeedback.$2 ||
                              !scanFeedback.$3 ||
                              !scanFeedback.$4))
                        const Text(
                          'Scanning needs WiFi, location services and scan permission. Existing samples are kept; only fresh observations add samples.',
                        ),
                      Text(
                        scanFeedback.$5
                            ? 'Scan request in progress.'
                            : scanFeedback.$6
                            ? 'Latest results are cached. No fresh samples added.'
                            : 'Waiting for the next foreground scan reply.',
                      ),
                      Text(
                        scanFeedback.$7 == null
                            ? 'No fresh observation received yet.'
                            : 'Last fresh observation ${_time(scanFeedback.$7!)}',
                      ),
                      TextButton.icon(
                        onPressed: () {
                          WaveHaptics.selection();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Return to Overview'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const SessionPolicy(),
              const SizedBox(height: 24),
              const SectionHeading(
                title: 'Saved sessions',
                subtitle: 'Select sessions for private export, or two or more to compare. Keep the same BSSID and source.',
              ),
              const SizedBox(height: 12),
              if (!sessions.loading && sessions.sessions.isEmpty)
                const EmptyState(
                  text: 'Your first room comparison starts here. Record, stop and save, then repeat in another room.',
                ),
              ...sessions.sessions.map((session) {
                final compatible =
                    selected.isEmpty ||
                    (selected.first.bssid == session.bssid &&
                        selected.first.demo == session.demo);
                return SavedSessionTile(
                  session: session,
                  alias: preferences[preferenceKey(session.bssid)]?.alias,
                  selected: _selected.contains(session.id),
                  onSelect: compatible
                      ? (value) {
                          WaveHaptics.selection();
                          setState(() {
                            value
                                ? _selected.add(session.id)
                                : _selected.remove(session.id);
                          });
                        }
                      : null,
                  onDelete: () async {
                    if (await _confirm(
                          context,
                          'Delete saved session?',
                          session.label.isEmpty ? session.ssid : session.label,
                          'Delete',
                        ) &&
                        mounted) {
                      WaveHaptics.selection();
                      vm.delete(session.id);
                      setState(() => _selected.remove(session.id));
                    }
                  },
                );
              }),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: () {
                    WaveHaptics.selection();
                    setState(_selected.clear);
                  },
                  child: const Text('Clear selection'),
                ),
              if (selected.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    WaveHaptics.selection();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ComparisonExportPage(sessions: selected),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Preview private export'),
                ),
              if (selected.length >= 2)
                WaveReveal(child: SessionComparison(sessions: selected)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class RecordingPanel extends StatelessWidget {
  const RecordingPanel({
    super.key,
    required this.session,
    required this.onStop,
    required this.onCancel,
  });
  final ComparisonSession session;
  final VoidCallback onStop, onCancel;
  @override
  Widget build(BuildContext context) => WavePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: session.demo
              ? 'Simulated session running'
              : 'Recording fresh observations',
          subtitle: '${_sessionName(session)} · ${session.bssid}',
        ),
        const SizedBox(height: 16),
        WaveValue(
          _sampleCount(session.samples.length),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Started ${_time(session.start)}. Counters update when scan replies arrive; silence adds no samples.',
        ),
        Text(
          session.samples.isEmpty
              ? 'Waiting for a fresh observation. Existing scan results are not added.'
              : 'Last sample ${_time(session.samples.last.at)} · ${session.samples.last.rssi} dBm',
        ),
        Text(
          '${session.cachedBatches} updates without fresh data · ${session.missingBatches} updates without this AP',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop and save'),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('Discard recording'),
            ),
          ],
        ),
      ],
    ),
  );
}

class SessionPolicy extends StatelessWidget {
  const SessionPolicy({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'Foreground only. Pause, background or changing source ends and saves recording; resume starts no recording. Relaunch restores saved sessions. Force-closing can lose an unfinished recording. Cached results and missing APs add no samples. Up to $maxComparisonSessions sessions and $maxSessionSamples samples per session. Labels stay on this device unless explicitly included in a reviewed export.',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class SavedSessionTile extends StatelessWidget {
  const SavedSessionTile({
    super.key,
    required this.session,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    this.alias,
  });
  final ComparisonSession session;
  final String? alias;
  final bool selected;
  final ValueChanged<bool>? onSelect;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                container: true,
                child: Checkbox(
                  semanticLabel:
                      'Select ${_sessionName(session)}, ${alias == null ? session.ssid : '$alias (${session.ssid})'}, ${session.bssid}, ${session.demo ? 'simulated' : 'measured'} for comparison',
                  value: selected,
                  onChanged: onSelect == null
                      ? null
                      : (value) => onSelect!(value!),
                ),
              ),
              Expanded(
                child: Text(
                  _sessionName(session),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Delete ${_sessionName(session)}',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alias == null ? (session.ssid.isEmpty ? 'Hidden network' : session.ssid) : '$alias (${session.ssid.isEmpty ? 'Hidden network' : session.ssid})'} · ${session.bssid}',
                ),
                Text(
                  '${session.demo ? 'SIMULATED · ' : ''}${_sampleCount(session.samples.length)} · ${_time(session.start)} – ${session.end == null ? 'running' : _time(session.end!)}',
                ),
                Text(
                  '${session.reason} · ${session.groups.length} radio context${session.groups.length == 1 ? '' : 's'}',
                ),
                if (onSelect == null)
                  const Text(
                    'Different BSSID or source. Clear selection to compare this AP.',
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SessionComparison extends StatelessWidget {
  const SessionComparison({super.key, required this.sessions});
  final List<ComparisonSession> sessions;
  @override
  Widget build(BuildContext context) {
    if (sessions.length < 2 ||
        sessions.any(
          (s) =>
              preferenceKey(s.bssid) != preferenceKey(sessions.first.bssid) ||
              s.demo != sessions.first.demo,
        )) {
      return const WavePanel(
        child: Text(
          'Choose at least two sessions for the same BSSID and source.',
        ),
      );
    }
    final first = sessions.first;
    final groups = {for (final session in sessions) session.id: session.groups};
    final firstGroups = groups[first.id]!;
    final matching =
        firstGroups.length == 1 &&
        sessions.every(
          (s) =>
              groups[s.id]!.length == 1 &&
              groups[s.id]!.keys.first == firstGroups.keys.first,
        );
    return WavePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Compare rooms',
            subtitle: '${first.demo ? 'SIMULATED · ' : ''}${first.bssid}',
          ),
          const SizedBox(height: 12),
          if (!matching)
            const Text(
              'Radio context changed or observations are missing. Read each band/channel/width separately; no combined signal delta.',
            ),
          if (matching)
            const Text(
              'Same radio context. Positive median delta means stronger received signal, not faster WiFi.',
            ),
          const Text(
            'Only observed samples are compared. Silence between observations is not filled or interpolated.',
          ),
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sessionName(session),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (session.samples.isEmpty)
                    const Text(
                      'No fresh samples. No signal comparison available.',
                    ),
                  ...groups[session.id]!.entries.map(
                    (group) => SessionMetrics(
                      contextLabel: group.key,
                      samples: group.value,
                    ),
                  ),
                  if (matching && session.id != first.id)
                    Text(
                      'Median delta vs ${_sessionName(first)}: ${_delta(medianRssi(session.samples) - medianRssi(first.samples))} dB',
                    ),
                  if (session.samples.isNotEmpty && session.end != null)
                    Text(
                      'Longest session observation gap: ${_sessionGap(session).inSeconds} seconds',
                    ),
                  if (session.samples.isNotEmpty && session.end != null)
                    Text(
                      'Wait before first sample: ${session.samples.first.at.difference(session.start).inSeconds} seconds · silence before stop: ${session.end!.difference(session.samples.last.at).inSeconds} seconds',
                    ),
                  Text(
                    '${session.missingBatches} missing AP updates · ${session.cachedBatches} updates without fresh data',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionMetrics extends StatelessWidget {
  const SessionMetrics({
    super.key,
    required this.contextLabel,
    required this.samples,
  });
  final String contextLabel;
  final List<SessionSample> samples;
  @override
  Widget build(BuildContext context) {
    final values = samples.map((s) => s.rssi).toList()..sort();
    var longestGap = Duration.zero;
    for (var index = 1; index < samples.length; index++) {
      final gap = samples[index].at.difference(samples[index - 1].at);
      if (gap > longestGap) longestGap = gap;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contextLabel),
          Text(
            '${_sampleCount(samples.length)} · ${_time(samples.first.at)} – ${_time(samples.last.at)}',
          ),
          Text(
            'Median ${medianRssi(samples)} dBm · range ${values.first} to ${values.last} dBm',
          ),
          if (samples.length > 1)
            Text('Longest observation gap: ${longestGap.inSeconds} seconds'),
        ],
      ),
    );
  }
}

String _sampleCount(int count) => '$count sample${count == 1 ? '' : 's'}';

String _sessionName(ComparisonSession session) =>
    session.label.isEmpty ? 'Session ${_time(session.start)}' : session.label;
String _time(DateTime value) {
  final date = value.toLocal();
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}';
}

String _delta(num value) => '${value > 0 ? '+' : ''}$value';

Duration _sessionGap(ComparisonSession session) {
  var previous = session.start;
  var longest = Duration.zero;
  for (final sample in session.samples) {
    final gap = sample.at.difference(previous);
    if (gap > longest) longest = gap;
    previous = sample.at;
  }
  final tail = (session.end ?? previous).difference(previous);
  return tail > longest ? tail : longest;
}
