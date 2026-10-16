// Capture actual shared Flutter screens with explicit demo observations.
// Run manually: fvm flutter test tool/screenshots/capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const androidMobile = bool.fromEnvironment('WAVE_SCREENSHOT_ANDROID');
  const outputDirectory = String.fromEnvironment(
    'WAVE_SCREENSHOT_OUTPUT',
    defaultValue: 'docs/screenshots/raw',
  );
  setUpAll(() async {
    if (androidMobile) {
      // Demo captures never connect to an Android radio or native scan stream.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.samirpandey.wifi_analyser/scan_results'),
            (_) async => null,
          );
    }
    final sdk = Directory('.fvm/flutter_sdk').resolveSymbolicLinksSync();
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    // Production theme requests Arial; use the system face where available.
    // Other hosts use Flutter's Roboto fallback, without shipping font binaries.
    const systemFont = '/System/Library/Fonts/Supplemental/Arial.ttf';
    await loadFont(
      'Arial',
      File(systemFont).existsSync()
          ? [systemFont, '/System/Library/Fonts/Supplemental/Arial Bold.ttf']
          : ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Bold.ttf'],
    );
    const mono = '/System/Library/Fonts/Supplemental/Courier New.ttf';
    await loadFont('monospace', [
      File(mono).existsSync() ? mono : '$fonts/Roboto-Regular.ttf',
    ]);
    await loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  for (final capture in [
    (name: 'mobile-overview-light', desktop: false, dark: false, page: 0),
    (name: 'mobile-spectrum-dark', desktop: false, dark: true, page: 1),
    (name: 'mobile-networks-light', desktop: false, dark: false, page: 2),
    (name: 'desktop-overview-dark', desktop: true, dark: true, page: 0),
    (name: 'desktop-spectrum-light', desktop: true, dark: false, page: 1),
  ]) {
    if (androidMobile && capture.desktop) continue;
    testWidgets('capture ${capture.name}', (tester) async {
      debugDefaultTargetPlatformOverride = capture.desktop
          ? TargetPlatform.macOS
          : androidMobile
          ? TargetPlatform.android
          : TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final size = capture.desktop
          ? const Size(1440, 1000)
          : const Size(430, 932);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Capture harness uses in-memory preferences, never user storage.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({
        'onboardingComplete': true,
        'theme': capture.dark ? ThemeMode.dark.index : ThemeMode.light.index,
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              demoModeDefaultProvider.overrideWithValue(true),
              observationClockProvider.overrideWithValue(() => DateTime.now()),
            ],
            child: MediaQuery.fromView(
              view: tester.view,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: const WaveApp(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final appearance in ['light', 'dark']) {
          await precacheImage(
            AssetImage('assets/branding/wave-badge-$appearance.png'),
            key.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      if (capture.page > 0) {
        if (capture.desktop) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.sendKeyEvent(
            capture.page == 1
                ? LogicalKeyboardKey.digit2
                : LogicalKeyboardKey.digit3,
          );
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        } else {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(capture.page == 1 ? 'Spectrum' : 'Networks'),
            ),
          );
        }
        await tester.pumpAndSettle();
      }
      expect(find.text('Simulated data • no hardware scan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(
          pixelRatio: capture.desktop ? 1.5 : 3,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(outputDirectory).create(recursive: true);
        await File('$outputDirectory/${capture.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
