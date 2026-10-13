import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/ap_preference.dart';
import '../repositories/ap_preferences_repository.dart';

class ApPreferencesState {
  ApPreferencesState({
    Map<String, ApPreference> entries = const {},
    this.loading = false,
    this.saving = false,
    this.error,
  }) : entries = Map.unmodifiable(entries);
  final Map<String, ApPreference> entries;
  final bool loading, saving;
  final String? error;
}

final apPreferencesProvider =
    NotifierProvider<ApPreferencesViewModel, ApPreferencesState>(
      ApPreferencesViewModel.new,
    );

class ApPreferencesViewModel extends Notifier<ApPreferencesState> {
  late ApPreferencesRepository _repository;
  final Map<String, _PreferencePatch> _edits = {};
  bool _loaded = false, _writing = false;
  int _revision = 0;
  String? _notice;
  @override
  ApPreferencesState build() {
    _repository = ref.read(apPreferencesRepositoryProvider);
    unawaited(Future.microtask(_load));
    return ApPreferencesState(loading: true);
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = ApPreferencesState(entries: state.entries, loading: true);
    try {
      final saved = await _repository.load();
      if (!ref.mounted) return;
      final merged = {...saved};
      for (final edit in _edits.entries) {
        final entry = edit.value.apply(merged[edit.key]);
        if (!entry.favorite && entry.alias == null) {
          merged.remove(edit.key);
        } else {
          merged[edit.key] = entry;
        }
      }
      if (merged.length > maxApPreferences) {
        // Preserve every hydrated identity. Reject only newly added identities
        // when hydration reveals that the existing store was already full.
        final additions = merged.keys
            .where((key) => !saved.containsKey(key))
            .toList();
        for (final key in additions.reversed) {
          if (merged.length <= maxApPreferences) break;
          merged.remove(key);
          _edits.remove(key);
        }
        _loaded = true;
        _notice = 'Saved AP limit reached. Some new choices could not be added. Remove a favorite or alias before adding another AP.';
        state = ApPreferencesState(entries: merged, error: _notice);
        if (_edits.isNotEmpty) unawaited(_save());
        return;
      }
      _loaded = true;
      state = ApPreferencesState(entries: merged);
      if (_edits.isNotEmpty) unawaited(_save());
    } catch (_) {
      if (ref.mounted) {
        state = ApPreferencesState(
          entries: state.entries,
          error: 'Could not load AP preferences. Retry to recover saved choices; edits remain here.',
        );
      }
    }
  }

  void setFavorite(AccessPoint ap, bool favorite) =>
      updateSaved(_entry(ap), favorite: favorite);
  void setAlias(AccessPoint ap, String? alias) => updateSaved(
    _entry(ap),
    alias: alias,
    clearAlias: alias == null || alias.trim().isEmpty,
  );
  ApPreference _entry(AccessPoint ap) {
    final old = state.entries[preferenceKey(ap.bssid)];
    return ApPreference(
      bssid: preferenceKey(ap.bssid),
      ssid: ap.ssid,
      alias: old?.alias,
      favorite: old?.favorite ?? false,
    );
  }

  void updateSaved(
    ApPreference entry, {
    bool? favorite,
    String? alias,
    bool clearAlias = false,
  }) {
    final key = preferenceKey(entry.bssid);
    final name = clearAlias
        ? null
        : alias?.trim() ?? state.entries[key]?.alias ?? entry.alias;
    if (key.isEmpty ||
        key.length > 128 ||
        entry.ssid.length > 256 ||
        (name?.length ?? 0) > maxAliasLength) {
      return;
    }
    if (!_loaded &&
        !_edits.containsKey(key) &&
        _edits.length >= maxApPreferences) {
      state = ApPreferencesState(
        entries: state.entries,
        loading: state.loading,
        error: 'Too many pending AP edits. Retry loading preferences before editing another AP.',
      );
      return;
    }
    final next = ApPreference(
      bssid: key,
      ssid: entry.ssid,
      alias: name?.isEmpty == true ? null : name,
      favorite: favorite ?? state.entries[key]?.favorite ?? entry.favorite,
    );
    final entries = {...state.entries};
    if (next.favorite || next.alias != null) {
      if (!entries.containsKey(key) && entries.length >= maxApPreferences) {
        state = ApPreferencesState(
          entries: entries,
          loading: state.loading,
          saving: state.saving,
          error: 'Save up to 256 APs. Remove a favorite or alias first.',
        );
        return;
      }
      entries[key] = next;
    } else {
      entries.remove(key);
    }
    if (!_loaded) {
      final previous = _edits[key];
      _edits[key] = _PreferencePatch(
        bssid: key,
        ssid: entry.ssid,
        favorite: favorite ?? previous?.favorite,
        aliasChanged:
            clearAlias || alias != null || (previous?.aliasChanged ?? false),
        alias: clearAlias ? null : alias?.trim() ?? previous?.alias,
      );
    }
    _notice = null;
    _revision++;
    state = ApPreferencesState(
      entries: entries,
      loading: state.loading,
      saving: state.saving,
      error: _loaded ? null : state.error,
    );
    if (_loaded) unawaited(_save());
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
        final entries = state.entries;
        state = ApPreferencesState(
          entries: entries,
          saving: true,
          error: _notice,
        );
        try {
          await _repository.save(entries);
          if (!ref.mounted) return;
          if (revision == _revision) {
            _edits.clear();
            state = ApPreferencesState(entries: state.entries, error: _notice);
            return;
          }
        } catch (_) {
          if (!ref.mounted) return;
          if (revision != _revision) continue;
          state = ApPreferencesState(
            entries: state.entries,
            error: 'Could not save AP preferences. Choices remain here. Retry saving.',
          );
          return;
        }
      }
    } finally {
      _writing = false;
    }
  }
}

/// One bounded patch per identity, including explicit removal during hydration.
class _PreferencePatch {
  const _PreferencePatch({
    required this.bssid,
    required this.ssid,
    this.favorite,
    required this.aliasChanged,
    this.alias,
  });
  final String bssid, ssid;
  final bool? favorite;
  final bool aliasChanged;
  final String? alias;
  ApPreference apply(ApPreference? saved) => ApPreference(
    bssid: bssid,
    ssid: ssid,
    favorite: favorite ?? saved?.favorite ?? false,
    alias: aliasChanged
        ? (alias?.isEmpty == true ? null : alias)
        : saved?.alias,
  );
}
