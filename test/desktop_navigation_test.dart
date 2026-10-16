import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/views/analyser_navigation.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> launch(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoModeDefaultProvider.overrideWithValue(true)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              padding: const EdgeInsets.only(top: 28),
            ),
            child: child!,
          ),
          home: const AnalyserHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'medium desktop rail navigates with platform keys after resize',
    (tester) async {
      await launch(tester, const Size(800, 700));
      expect(find.byType(AnalyserRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.getTopLeft(find.byType(AnalyserRail)).dy, 28);
      final modifier = defaultTargetPlatform == TargetPlatform.windows
          ? LogicalKeyboardKey.controlLeft
          : LogicalKeyboardKey.metaLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      tester.view.physicalSize = const Size(600, 700);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.tap(find.text('Networks').last);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'short wide desktop keeps navigation reachable at large text',
    (tester) async {
      await launch(tester, const Size(1200, 480), scale: 1.8);
      expect(find.byType(AnalyserSidebar), findsOneWidget);
      final settings = find.descendant(
        of: find.byType(AnalyserSidebar),
        matching: find.text('Settings'),
      );
      await tester.ensureVisible(settings);
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
}
