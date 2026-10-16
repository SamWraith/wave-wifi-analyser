import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_home.dart';
import 'package:wifi_analyser/views/app_theme.dart';
import 'package:wifi_analyser/widgets/support_button.dart';

void main() {
  testWidgets('persistent button fits narrow screens at double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(body: Center(child: SupportBar())),
          ),
        ),
      ),
    );
    expect(find.byType(SupportButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (size, brightness, scale) in [
    (const Size(320, 700), Brightness.dark, 1.0),
    (const Size(800, 700), Brightness.light, 2.0),
    (const Size(1200, 480), Brightness.dark, 1.8),
  ]) {
    testWidgets('support stays visible across tabs at $size $brightness', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [demoModeDefaultProvider.overrideWithValue(true)],
          child: MaterialApp(
            theme: buildAppTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const AnalyserHome(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.descendant(
        of: find.byType(SupportBar),
        matching: find.byType(FilledButton),
      );
      final position = tester.getRect(button);
      for (final key in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getRect(button), position);
        expect(position.top, greaterThanOrEqualTo(0));
        expect(position.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      }
      // The support action remains pinned when the page scrolls.
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(button), position);
      expect(button.hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
