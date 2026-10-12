import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/models/onboarding_step.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/onboarding_page.dart';
import 'package:wifi_analyser/views/app_theme.dart';

/// Run in profile mode on physical hardware. Results describe this workload only.
Future<Map<String, Object>> sample(
  String name,
  Future<void> Function() action,
) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  final frames = <FrameTiming>[];
  void collect(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(collect);
  final start = developer.Timeline.now;
  late int end;
  try {
    await action();
    end = developer.Timeline.now;
    await Future<void>.delayed(const Duration(seconds: 2));
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
  final measured = frames
      .where(
        (f) =>
            f.timestampInMicroseconds(FramePhase.vsyncStart) >= start &&
            f.timestampInMicroseconds(FramePhase.vsyncStart) <= end,
      )
      .toList();
  expect(measured, isNotEmpty, reason: 'No real frame timings for $name');
  double percentile(List<double> values, double p) {
    values.sort();
    return values[((values.length - 1) * p).ceil()];
  }

  final build = measured
      .map((f) => f.buildDuration.inMicroseconds / 1000)
      .toList();
  final raster = measured
      .map((f) => f.rasterDuration.inMicroseconds / 1000)
      .toList();
  final cadence = <double>[];
  for (var i = 1; i < measured.length; i++) {
    final ms =
        (measured[i].timestampInMicroseconds(FramePhase.vsyncStart) -
            measured[i - 1].timestampInMicroseconds(FramePhase.vsyncStart)) /
        1000;
    if (ms > 0 && ms < 50) cadence.add(ms);
  }
  return {
    'scenario': name,
    'frames': measured.length,
    'buildP95Ms': percentile(build, .95),
    'rasterP95Ms': percentile(raster, .95),
    'buildMaxMs': build.reduce(math.max),
    'rasterMaxMs': raster.reduce(math.max),
    'framesOver120HzBudget': measured
        .where(
          (f) =>
              f.buildDuration.inMicroseconds > 8333 ||
              f.rasterDuration.inMicroseconds > 8333,
        )
        .length,
    if (cadence.isNotEmpty) 'activeVsyncMedianMs': percentile(cadence, .5),
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('physical device motion profile', (tester) async {
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaveApp)),
    );
    container.read(analyserProvider.notifier).togglePause();
    await tester.pumpAndSettle();
    Map<String, dynamic>? display;
    if (Platform.isAndroid) {
      display = await const MethodChannel(
        'com.samirpandey.wifi_analyser/display',
      ).invokeMapMethod<String, dynamic>('refreshRate');
    }
    final reports = <Map<String, Object>>[];
    Future<void> toggle() async {
      await tester.ensureVisible(find.byTooltip('Switch light / dark theme'));
      await tester.tap(find.byTooltip('Switch light / dark theme'));
      await tester.pump(const Duration(milliseconds: 800));
    }

    reports.add(await sample('first-theme-reveal', toggle));
    reports.add(
      await sample('repeated-theme-reveals', () async {
        for (var i = 0; i < 6; i++) {
          await toggle();
        }
      }),
    );
    reports.add(
      await sample('navigation-search-details', () async {
        for (final destination in ['Spectrum', 'Channels', 'Networks']) {
          await tester.tap(find.text(destination).last);
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.enterText(find.byType(TextField), 'Studio');
        await tester.pump(const Duration(milliseconds: 300));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Studio Network'));
        await tester.pump(const Duration(milliseconds: 500));
        Navigator.of(tester.element(find.text('Copy MAC address'))).pop();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Settings').last);
        await tester.pump(const Duration(milliseconds: 500));
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: OnboardingPage(onFinished: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final step in onboardingSteps) {
      final replay = find.widgetWithText(TextButton, step.action);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (replay.evaluate().isNotEmpty &&
            tester.widget<TextButton>(replay).onPressed != null) {
          break;
        }
      }
      expect(tester.widget<TextButton>(replay).onPressed, isNotNull);
      await tester.ensureVisible(replay);
      reports.add(
        await sample('rive-${step.artboard}', () async {
          for (var i = 0; i < 2; i++) {
            await tester.tap(replay);
            await tester.pump(const Duration(milliseconds: 1300));
          }
        }),
      );
      if (step != onboardingSteps.last) {
        final next = find.widgetWithText(FilledButton, 'Continue');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
    }
    final result = {
      'display': display,
      'scenarios': reports,
      'mode': 'profile',
      'qualification': 'Measured workload only; frame timings do not prove compositor presentation or all-device sustained fps.',
    };
    binding.reportData = result;
    debugPrint('WAVE_MOTION_PROFILE=${jsonEncode(result)}');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
