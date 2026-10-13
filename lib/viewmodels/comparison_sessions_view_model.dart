import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/ap_preference.dart';
import '../models/comparison_session.dart';
import '../repositories/comparison_sessions_repository.dart';

/// Observation times stay anchored to the start wall clock even if Android
/// corrects its clock during recording. Elapsed time never runs backwards.
abstract interface class SessionClock {
  DateTime now();
  Duration get elapsed;
}

class MonotonicSessionClock implements SessionClock {
  final _watch = Stopwatch()..start();
  @override
  DateTime now() => DateTime.now();
  @override
  Duration get elapsed => _watch.elapsed;
}

final sessionClockProvider = Provider<SessionClock>(
  (ref) => MonotonicSessionClock(),
);

class ComparisonSessionsState {
  ComparisonSessionsState({
    List<ComparisonSession> sessions = const [],
    this.active,
    this.loading = false,
    this.saving = false,
    this.error,
  }) : sessions = List.unmodifiable(sessions);
  final List<ComparisonSession> sessions;
  final ComparisonSession? active;
  final bool loading, saving;
  final String? error;
}

final comparisonSessionsProvider =
    NotifierProvider<ComparisonSessionsViewModel, ComparisonSessionsState>(
      ComparisonSessionsViewModel.new,
    );

class ComparisonSessionsViewModel extends Notifier<ComparisonSessionsState> {
  late ComparisonSessionsRepository _repository;
  late SessionClock _clock;
  Duration _startedElapsed = Duration.zero;
  late Future<void> ready;
  bool _loaded = false, _writing = false;
  int _revision = 0, _sequence = 0;
  bool get loaded => _loaded;
  @override
  ComparisonSessionsState build() {
    _repository = ref.read(comparisonSessionsRepositoryProvider);
    _clock = ref.read(sessionClockProvider);
    ready = Future.microtask(_load);
    return ComparisonSessionsState(loading: true);
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = ComparisonSessionsState(loading: true);
    try {
      final sessions = await _repository.load();
      if (!ref.mounted) return;
      _loaded = true;
      state = ComparisonSessionsState(sessions: sessions);
    } catch (_) {
      if (ref.mounted) {
        state = ComparisonSessionsState(
          error: 'Could not load saved sessions. Retry before recording; saved data has not been replaced.',
        );
      }
    }
  }

  bool start(AccessPoint ap, String label, {required bool demo}) {
    if (!_loaded || state.active != null) return false;
    if (state.sessions.length >= maxComparisonSessions) {
      state = ComparisonSessionsState(
        sessions: state.sessions,
        saving: state.saving,
        error: '24 sessions saved. Delete a session before recording.',
      );
      return false;
    }
    final name = label.trim();
    final key = preferenceKey(ap.bssid);
    if (name.length > maxSessionLabelLength ||
        key.isEmpty ||
        key.length > 128 ||
        ap.ssid.length > 256) {
      return false;
    }
    final now = _clock.now();
    _startedElapsed = _clock.elapsed;
    state = ComparisonSessionsState(
      sessions: state.sessions,
      saving: state.saving,
      error: state.error,
      active: ComparisonSession(
        id: '${now.microsecondsSinceEpoch}-${_sequence++}',
        bssid: key,
        ssid: ap.ssid,
        label: name,
        start: now,
        demo: demo,
      ),
    );
    return true;
  }

  /// Called only by analyser's accepted observation boundary. No chart filters,
  /// history replay, cached snapshots or initial UI values can create samples.
  void observe(
    List<AccessPoint> points,
    Map<String, AccessPoint> fresh, {
    required bool demo,
  }) {
    final active = state.active;
    if (active == null || active.demo != demo) return;
    final present = points.any((ap) => preferenceKey(ap.bssid) == active.bssid);
    final target = fresh[active.bssid];
    final next = active.update(
      sample: target != null
          ? SessionSample(
              at: _recordedAt(active),
              rssi: target.rssi,
              frequency: target.frequency,
              width: target.width,
              centerFrequency: target.centerFrequency,
            )
          : null,
      missing: !present,
      cached: present && target == null,
    );
    state = ComparisonSessionsState(
      sessions: state.sessions,
      active: next,
      saving: state.saving,
      error: state.error,
    );
    if (next.samples.length >= maxSessionSamples) {
      stop('120-sample limit reached');
    }
  }

  DateTime _recordedAt(ComparisonSession active) =>
      active.start.add(_clock.elapsed - _startedElapsed);

  void stop([String reason = 'Stopped by you']) {
    final active = state.active;
    if (active == null) return;
    _revision++;
    state = ComparisonSessionsState(
      sessions: [
        ...state.sessions,
        active.update(end: _recordedAt(active), reason: reason),
      ],
      saving: state.saving,
    );
    unawaited(_save());
  }

  void cancel() {
    state = ComparisonSessionsState(
      sessions: state.sessions,
      saving: state.saving,
      error: state.error,
    );
  }

  void delete(String id) {
    if (!_loaded) return;
    _revision++;
    state = ComparisonSessionsState(
      sessions: state.sessions.where((s) => s.id != id).toList(),
      active: state.active,
      saving: state.saving,
    );
    unawaited(_save());
  }

  Future<void> retry() async {
    if (state.loading || _writing) return;
    if (!_loaded) {
      await _load();
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    if (_writing || !ref.mounted) return;
    _writing = true;
    try {
      while (ref.mounted) {
        final revision = _revision;
        final sessions = state.sessions;
        state = ComparisonSessionsState(
          sessions: sessions,
          active: state.active,
          saving: true,
        );
        try {
          await _repository.save(sessions);
          if (!ref.mounted) return;
          if (revision != _revision) continue;
          state = ComparisonSessionsState(
            sessions: state.sessions,
            active: state.active,
          );
          return;
        } catch (_) {
          if (!ref.mounted) return;
          if (revision != _revision) continue;
          state = ComparisonSessionsState(
            sessions: state.sessions,
            active: state.active,
            error: 'Could not save sessions. Changes remain here until app closes. Retry saving.',
          );
          return;
        }
      }
    } finally {
      _writing = false;
    }
  }
}
