import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/onboarding_repository.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/onboarding_view_model.dart';
import 'package:wifi_analyser/widgets/onboarding_illustration.dart';
import 'package:wifi_analyser/views/onboarding_page.dart';
import 'package:wifi_analyser/views/app_theme.dart';

class _WelcomeStore implements OnboardingRepository {
  bool completed = false, failSave = false, failLoad = false;
  int writes = 0;
  Completer<bool>? pendingLoad;
  Completer<void>? pendingSave;
  @override
  Future<bool> isComplete() async {
    if (failLoad) throw StateError('load failed');
    return pendingLoad == null ? completed : pendingLoad!.future;
  }

  @override
  Future<void> complete() async {
    writes++;
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('save failed');
    completed = true;
  }
}

class _WifiProbe implements WifiRepository {
  int calls = 0;
  @override
  bool get supported => true;
  @override
  Stream<WifiSnapshot> get scanResults => const Stream.empty();
  @override
  Future<WifiSnapshot> snapshot() async {
    calls++;
    return WifiSnapshot(
      permission: false,
      locationEnabled: false,
      wifiEnabled: false,
      status: 'Unavailable',
      accessPoints: const [],
    );
  }

  @override
  Future<WifiSnapshot> scan() => snapshot();
  @override
  Future<bool> requestPermission() async {
    calls++;
    return false;
  }

  @override
  Future<void> openSettings() async {
    calls++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester,
    _WelcomeStore store,
    _WifiProbe wifi,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(store),
          wifiRepositoryProvider.overrideWithValue(wifi),
          onboardingArtProvider.overrideWithValue(
            (step) => SizedBox(height: 180, child: Text(step.artboard)),
          ),
        ],
        child: const WaveApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first launch waits for storage and never scans before completion',
    (tester) async {
      final store = _WelcomeStore()..pendingLoad = Completer<bool>();
      final wifi = _WifiProbe();
      await launch(tester, store, wifi);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(wifi.calls, 0);
      store.pendingLoad!.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Meet your\nnetwork.'), findsOneWidget);
      await press(tester, 'Continue');
      expect(find.text('Less overlap.\nMore clarity.'), findsOneWidget);
      await press(tester, 'Back');
      expect(find.text('Meet your\nnetwork.'), findsOneWidget);
      await press(tester, 'Continue');
      await press(tester, 'Continue');
      expect(find.text('Ready when\nyou are.'), findsOneWidget);
      expect(wifi.calls, 0);
      await press(tester, 'Start exploring');
      expect(store.completed, isTrue);
      expect(store.writes, 1);
      expect(find.text('Know your WiFi.'), findsOneWidget);
      expect(wifi.calls, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed completion preserves current step and retry succeeds', (
    tester,
  ) async {
    final store = _WelcomeStore()..failSave = true;
    final wifi = _WifiProbe();
    await launch(tester, store, wifi);
    await press(tester, 'Continue');
    await press(tester, 'Continue');
    await press(tester, 'Start exploring');
    expect(find.text('Ready when\nyou are.'), findsOneWidget);
    expect(
      find.text('Could not save your choice. Tap again to retry.'),
      findsOneWidget,
    );
    expect(wifi.calls, 0);
    store.failSave = false;
    await press(tester, 'Start exploring');
    expect(store.completed, isTrue);
    expect(find.byType(OnboardingPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'skip coalesces pending saves and stored completion skips next launch',
    (tester) async {
      final store = _WelcomeStore()..pendingSave = Completer<void>();
      await launch(tester, store, _WifiProbe());
      await press(tester, 'Skip');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WaveApp)),
      );
      await container.read(onboardingProvider.notifier).complete();
      expect(store.writes, 1);
      expect(find.text('Saving…'), findsOneWidget);
      store.pendingSave!.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await launch(tester, store, _WifiProbe());
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.text('Know your WiFi.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed load remains usable and disposed late load is ignored', (
    tester,
  ) async {
    final store = _WelcomeStore()..failLoad = true;
    await launch(tester, store, _WifiProbe());
    expect(
      find.text('Could not load welcome preferences. You can still continue.'),
      findsOneWidget,
    );
    await press(tester, 'Skip');
    expect(store.completed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    final pending = _WelcomeStore()..pendingLoad = Completer<bool>();
    await launch(tester, pending, _WifiProbe());
    await tester.pumpWidget(const SizedBox.shrink());
    pending.pendingLoad!.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('local completion persists across repository instances', () async {
    final store = LocalOnboardingRepository();
    expect(await store.isComplete(), isFalse);
    await store.complete();
    expect(await LocalOnboardingRepository().isComplete(), isTrue);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1440, 1000),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'welcome fits $size in $brightness with large text and reduced motion',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var finished = 0;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingArtProvider.overrideWithValue(
                  (step) => const SizedBox(height: 160),
                ),
              ],
              child: MaterialApp(
                theme: buildAppTheme(brightness),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    disableAnimations: true,
                    textScaler: TextScaler.linear(1.8),
                  ),
                  child: OnboardingPage(onFinished: () => finished++),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await press(tester, 'Continue');
          await press(tester, 'Continue');
          await press(tester, 'Start exploring');
          expect(finished, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
