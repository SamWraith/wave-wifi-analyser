import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native theme reveal, retained search and all destinations', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    await prefs.setInt('theme', ThemeMode.light.index);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoModeDefaultProvider.overrideWithValue(true)],
        child: const WaveApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      const display = MethodChannel('com.samirpandey.wifi_analyser/display');
      final rates = (await display.invokeMapMethod<String, dynamic>(
        'refreshRate',
      ))!;
      final supported = (rates['supportedRefreshRates'] as List).cast<num>();
      expect(supported, isNotEmpty);
      expect(
        (rates['requestedRefreshRate'] as num).toDouble(),
        closeTo(supported.reduce(math.max).toDouble(), .1),
      );
      debugPrint(
        'Display refresh diagnostics: $rates (not a frame-rate benchmark)',
      );
    }
    await tester.tap(find.text('Networks').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studio');
    await tester.pumpAndSettle();
    final fieldState = tester.state(find.byType(TextField));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaveApp)),
    );
    for (final theme in [ThemeMode.dark, ThemeMode.light]) {
      await tester.ensureVisible(find.byTooltip('Switch light / dark theme'));
      await tester.tap(find.byTooltip('Switch light / dark theme'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (container.read(analyserProvider).themeMode == theme) break;
      }
      expect(container.read(analyserProvider).themeMode, theme);
      expect(
        find.byKey(const ValueKey('theme-reveal-overlay')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(
        identical(fieldState, tester.state(find.byType(TextField))),
        isTrue,
      );
      expect(find.text('Studio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    for (final destination in [
      'Spectrum',
      'Channels',
      'Settings',
      'Overview',
    ]) {
      await tester.tap(find.text(destination).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (container.read(analyserProvider).themeMode == ThemeMode.dark) break;
    }
    expect(container.read(analyserProvider).themeMode, ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(prefs.getInt('theme'), ThemeMode.dark.index);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
