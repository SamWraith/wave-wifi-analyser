import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/models/onboarding_step.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/views/onboarding_page.dart';

/// Profile-only entry point using the production binding and real frame clock.
/// Runs demo data, marks onboarding complete and changes persisted theme.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboardingComplete', true);
  runApp(
    ProviderScope(
      key: const ValueKey('motion-probe-app'),
      overrides: [demoModeDefaultProvider.overrideWithValue(true)],
      child: const WaveApp(),
    ),
  );
  await _wait(3000);
  final app = _find((e) => e.widget is WaveApp)!;
  ProviderScope.containerOf(app).read(analyserProvider.notifier).togglePause();
  final reports = <Map<String, Object>>[];
  reports.add(
    await _sample('normal-binding-theme-reveals', () async {
      for (var i = 0; i < 8; i++) {
        final button = _find(
          (e) =>
              e.widget is IconButton &&
              (e.widget as IconButton).tooltip == 'Switch light / dark theme',
        )!;
        (button.widget as IconButton).onPressed!.call();
        await _wait(1000);
      }
    }),
  );
  runApp(
    ProviderScope(
      key: const ValueKey('motion-probe-onboarding'),
      child: MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: OnboardingPage(onFinished: () {}),
      ),
    ),
  );
  for (final step in onboardingSteps) {
    final replay = await _readyButton(step.action);
    reports.add(
      await _sample('normal-binding-rive-${step.artboard}', () async {
        for (var i = 0; i < 3; i++) {
          (replay.widget as TextButton).onPressed!.call();
          await _wait(1400);
        }
      }),
    );
    if (step != onboardingSteps.last) {
      final next = await _readyButton('Continue');
      (next.widget as FilledButton).onPressed!.call();
      await _wait(800);
    }
  }
  final display = Platform.isAndroid
      ? await const MethodChannel('com.samirpandey.wifi_analyser/display')
            .invokeMapMethod<String, dynamic>('refreshRate')
      : null;
  debugPrint(
    'WAVE_NORMAL_MOTION_PROFILE=${jsonEncode({'mode': 'profile', 'binding': 'WidgetsFlutterBinding', 'display': display, 'scenarios': reports, 'qualification': 'Sampled real-runtime frame timings, not compositor presentation or a constant-fps guarantee.'})}',
  );
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Element? _find(bool Function(Element) matches) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (matches(element)) {
      found = element;
      return;
    }
    element.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return found;
}

bool _containsText(Element element, String label) {
  var contains =
      element.widget is Text && (element.widget as Text).data == label;
  element.visitChildElements((child) {
    contains = contains || _containsText(child, label);
  });
  return contains;
}

Future<Element> _readyButton(String label) async {
  for (var i = 0; i < 100; i++) {
    final element = _find((e) {
      final widget = e.widget;
      final enabled =
          widget is TextButton && widget.onPressed != null ||
          widget is FilledButton && widget.onPressed != null;
      return enabled && _containsText(e, label);
    });
    if (element != null) return element;
    await _wait(50);
  }
  throw StateError('Button not ready: $label');
}

Future<Map<String, Object>> _sample(
  String scenario,
  Future<void> Function() action,
) async {
  await _wait(2000);
  final frames = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => frames.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  final start = developer.Timeline.now;
  late int end;
  try {
    await action();
    end = developer.Timeline.now;
    await _wait(2000);
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
  if (measured.isEmpty) throw StateError('No frame timings: $scenario');
  final result = _metrics(scenario, measured);
  debugPrint('WAVE_NORMAL_SAMPLE=${jsonEncode(result)}');
  return result;
}

Map<String, Object> _metrics(String scenario, List<FrameTiming> frames) {
  double p95(List<double> values) {
    values.sort();
    return values[((values.length - 1) * .95).ceil()];
  }

  final build = frames
      .map((f) => f.buildDuration.inMicroseconds / 1000)
      .toList();
  final raster = frames
      .map((f) => f.rasterDuration.inMicroseconds / 1000)
      .toList();
  final cadence = <double>[];
  for (var i = 1; i < frames.length; i++) {
    final delta =
        (frames[i].timestampInMicroseconds(FramePhase.vsyncStart) -
            frames[i - 1].timestampInMicroseconds(FramePhase.vsyncStart)) /
        1000;
    if (delta > 0 && delta < 40) cadence.add(delta);
  }
  cadence.sort();
  return {
    'scenario': scenario,
    'frames': frames.length,
    'buildP95Ms': p95(build),
    'rasterP95Ms': p95(raster),
    'buildMaxMs': build.reduce(math.max),
    'rasterMaxMs': raster.reduce(math.max),
    'framesOver120HzBudget': frames
        .where(
          (f) =>
              f.buildDuration.inMicroseconds > 8333 ||
              f.rasterDuration.inMicroseconds > 8333,
        )
        .length,
    if (cadence.isNotEmpty) 'activeVsyncMedianMs': cadence[cadence.length ~/ 2],
    'activeIntervalsOver120HzBudget': cadence.where((ms) => ms > 9).length,
  };
}
