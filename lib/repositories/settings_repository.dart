import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyserPreferences {
  const AnalyserPreferences(this.themeMode, this.minimumRssi);
  final ThemeMode themeMode;
  final int minimumRssi;
}

abstract interface class SettingsRepository {
  Future<AnalyserPreferences> load();
  Future<void> saveTheme(ThemeMode mode);
  Future<void> saveMinimum(int value);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => LocalSettingsRepository(),
);

class LocalSettingsRepository implements SettingsRepository {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  @override
  Future<AnalyserPreferences> load() async {
    final prefs = await _prefs;
    return AnalyserPreferences(
      ThemeMode.values[prefs.getInt('theme')?.clamp(0, 2) ?? 0],
      prefs.getInt('minimumRssi')?.clamp(-95, -40) ?? -95,
    );
  }

  @override
  Future<void> saveTheme(ThemeMode mode) async {
    await (await _prefs).setInt('theme', mode.index);
  }

  @override
  Future<void> saveMinimum(int value) async {
    await (await _prefs).setInt('minimumRssi', value);
  }
}
