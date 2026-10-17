import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_analyser/viewmodels/export_cache_view_model.dart';
import 'package:wifi_analyser/views/settings_page.dart';

void main() {
  testWidgets(
    'clear exports requires confirmation, waits and reports completion',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportCacheCleanupProvider.overrideWithValue(() {
              calls++;
              return pending.future;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ExportCacheCard()),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Clear temporary exports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Clear temporary exports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear files'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Clearing…'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Temporary exports cleared.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed export cleanup reports retry and restores button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportCacheCleanupProvider.overrideWithValue(
            () async => throw StateError('private path must not reach UI'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ExportCacheCard())),
      ),
    );
    await tester.tap(find.text('Clear temporary exports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear files'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not clear temporary exports. Retry.'),
      findsOneWidget,
    );
    expect(find.text('Clear temporary exports'), findsOneWidget);
    expect(find.textContaining('private path'), findsNothing);
  });
}
