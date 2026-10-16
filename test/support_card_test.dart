import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/repositories/support_repository.dart';
import 'package:wifi_analyser/widgets/support_card.dart';

class FakeSupportRepository extends SupportRepository {
  final result = Completer<bool>();
  int calls = 0;

  @override
  Future<bool> openPage() {
    calls++;
    return result.future;
  }
}

Future<void> showCard(WidgetTester tester, FakeSupportRepository repository) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SupportCard())),
        ),
      ),
    );

void main() {
  testWidgets('opens once while pending and restores button after failure', (
    tester,
  ) async {
    final repository = FakeSupportRepository();
    await showCard(tester, repository);
    await tester.tap(find.text('Buy me a coffee'));
    await tester.pump();
    expect(find.text('Opening browser…'), findsOneWidget);
    await tester.tap(find.text('Opening browser…'));
    expect(repository.calls, 1);
    repository.result.complete(false);
    await tester.pump();
    expect(find.text('Buy me a coffee'), findsOneWidget);
    expect(find.textContaining('Could not open your browser.'), findsOneWidget);
  });

  testWidgets('handles platform errors without breaking settings', (
    tester,
  ) async {
    final repository = FakeSupportRepository();
    await showCard(tester, repository);
    await tester.tap(find.text('Buy me a coffee'));
    repository.result.completeError(StateError('No browser available'));
    await tester.pump();
    expect(find.textContaining('Could not open your browser.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores completion after settings closes', (tester) async {
    final repository = FakeSupportRepository();
    await showCard(tester, repository);
    await tester.tap(find.text('Buy me a coffee'));
    await tester.pumpWidget(const SizedBox());
    repository.result.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits narrow layout with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: SingleChildScrollView(child: SupportCard()),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Buy me a coffee'), findsOneWidget);
    });
  }
}
