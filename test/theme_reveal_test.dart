import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/widgets/theme_reveal.dart';
import 'package:wifi_analyser/widgets/wave_haptics.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.reduced = false, this.captureFrame});
  final bool reduced;
  final Future<ui.Image> Function(RenderRepaintBoundary, double)? captureFrame;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool dark = false;
  int changes = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: widget.reduced),
      child: ThemeReveal(captureFrame: widget.captureFrame, child: child!),
    ),
    home: Scaffold(
      body: Column(
        children: [
          const TextField(),
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ThemeReveal.change(context, () {
                changes++;
                setState(() => dark = !dark);
              }),
              child: const Text('Theme'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<int> opacityAt(WidgetTester tester, Offset point) async {
  final finder = find.byKey(const ValueKey('theme-reveal-overlay'));
  final size = tester.getSize(finder);
  final painter = tester.widget<CustomPaint>(finder).painter!;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await tester.runAsync(
    () => picture.toImage(size.width.round(), size.height.round()),
  );
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final alpha = bytes!.getUint8(
    (point.dy.floor() * size.width.round() + point.dx.floor()) * 4 + 3,
  );
  image!.dispose();
  picture.dispose();
  return alpha;
}

Future<void> captureFrame(WidgetTester tester) async {
  await tester.pump();
  // Engine raster readback is asynchronous, outside the fake frame clock.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pump();
}

void main() {
  testWidgets('theme reveal preserves text state and runs in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studio');
    final fieldState = tester.state(find.byType(TextField));
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    for (final dark in [true, false]) {
      await tester.tap(find.text('Theme'));
      await captureFrame(tester);
      expect(harness.dark, dark);
      expect(await opacityAt(tester, const Offset(700, 500)), 255);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(await opacityAt(tester, tester.getCenter(find.text('Theme'))), 0);
      expect(await opacityAt(tester, const Offset(700, 500)), 255);
      expect(harness.changes, dark ? 1 : 2);
      expect(
        identical(fieldState, tester.state(find.byType(TextField))),
        isTrue,
      );
      expect(find.text('Studio'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ThemeReveal),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion applies theme immediately without capture', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(reduced: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    expect(harness.dark, isTrue);
    expect(harness.changes, 1);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps coalesce and disposal ignores pending capture', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    await tester.tap(find.text('Theme'));
    await tester.tap(find.text('Theme'));
    await captureFrame(tester);
    expect(harness.changes, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(harness.changes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessibility enabled during capture skips reveal', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpWidget(const _Harness(reduced: true));
    await captureFrame(tester);
    expect(tester.state<_HarnessState>(find.byType(_Harness)).dark, isTrue);
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale capture failure cannot unlock or clear newer request', (
    tester,
  ) async {
    final captures = <Completer<ui.Image>>[];
    await tester.pumpWidget(
      _Harness(
        captureFrame: (_, _) {
          final completer = Completer<ui.Image>();
          captures.add(completer);
          return completer.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pump();
    expect(captures, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('Theme'));
    await tester.pump();
    expect(captures, hasLength(2));
    captures.first.completeError(StateError('stale readback'));
    await tester.pump();
    await tester.tap(find.text('Theme'));
    await tester.pump();
    expect(captures, hasLength(2));
    expect(tester.state<_HarnessState>(find.byType(_Harness)).changes, 0);
    captures.last.completeError(StateError('current readback'));
    await tester.pumpAndSettle();
    expect(tester.state<_HarnessState>(find.byType(_Harness)).changes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active reveal ends on reduced motion or window resize', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Retained');
    final fieldState = tester.state(find.byType(TextField));
    await tester.tap(find.text('Theme'));
    await captureFrame(tester);
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsOneWidget);
    await tester.pumpWidget(const _Harness(reduced: true));
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsNothing);
    expect(identical(fieldState, tester.state(find.byType(TextField))), isTrue);
    expect(tester.state<_HarnessState>(find.byType(_Harness)).dark, isTrue);
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await captureFrame(tester);
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsOneWidget);
    tester.view.physicalSize = const Size(700, 700);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();
    expect(find.byKey(const ValueKey('theme-reveal-overlay')), findsNothing);
    expect(identical(fieldState, tester.state(find.byType(TextField))), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mobile feedback uses native selection and light impact', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    WaveHaptics.selection();
    WaveHaptics.impact();
    await tester.pump();
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
    ]);
  });
}
