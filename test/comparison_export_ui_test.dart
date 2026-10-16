import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/models/comparison_export.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/repositories/comparison_share_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/viewmodels/ap_preferences_view_model.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/views/comparison_export_page.dart';
import 'package:wifi_analyser/views/sessions_page.dart';
import 'package:wifi_analyser/widgets/comparison_export_preview.dart';

import 'comparison_export_test.dart' show evidence;
import 'comparison_sessions_test.dart' show MemorySessions;

class _Share implements ComparisonShareRepository {
  int calls = 0;
  ComparisonExport? export;
  ComparisonShareResult result = ComparisonShareResult.cancelled;
  Completer<ComparisonShareResult>? reply;
  bool fail = false;
  @override
  Future<ComparisonShareResult> share(
    ComparisonExport export,
    Rect origin, {
    bool Function()? isCurrent,
  }) async {
    calls++;
    this.export = export;
    if (fail) throw StateError('Private native exception');
    return reply == null ? result : await reply!.future;
  }
}

class _Scan extends AnalyserViewModel {
  @override
  AnalyserState build() => AnalyserState(demo: true);
}

class _Preferences extends ApPreferencesViewModel {
  @override
  ApPreferencesState build() => ApPreferencesState();
}

void main() {
  late ProviderContainer container;
  late _Share share;
  late List<ComparisonSession> records;
  setUp(() async {
    records = [evidence(), evidence(id: 'two', label: 'Second private room')];
    share = _Share();
    container = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(
          MemorySessions()..saved = records,
        ),
        comparisonShareRepositoryProvider.overrideWithValue(share),
        analyserProvider.overrideWith(_Scan.new),
        apPreferencesProvider.overrideWith(_Preferences.new),
      ],
    );
    await container.read(comparisonSessionsProvider.notifier).ready;
  });
  tearDown(() => container.dispose());
  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    bool reduced = false,
    Widget? home,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: home ?? ComparisonExportPage(sessions: records),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saved selection discovers preview and return preserves selection; no automatic sharing',
    (tester) async {
      await show(tester, home: const SessionsPage());
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w is Checkbox &&
              w.semanticLabel?.startsWith('Select Private WiFi,') == true,
        ),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, find.byType(Checkbox).first);
      await tester.scrollUntilVisible(
        find.text('Preview private export'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, find.text('Preview private export'));
      expect(find.text('Review comparison export'), findsOneWidget);
      expect(share.calls, 0);
      expect(find.textContaining('Private WiFi'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ComparisonExportPage), findsNothing);
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w is Checkbox &&
              w.semanticLabel?.startsWith('Select Private WiFi,') == true,
        ),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      expect(share.calls, 0);
    },
  );
  testWidgets(
    'privacy opt-ins regenerate both exact previews and shared payload; cancellation retries',
    (tester) async {
      await show(tester);
      await tap(tester, find.text('Include SSID and BSSID'));
      await tap(tester, find.text('Include room labels'));
      await tap(tester, find.text('CSV preview'));
      final preview = tester.widget<ComparisonExportPreview>(
        find.byType(ComparisonExportPreview),
      );
      expect(
        preview.text,
        serializeComparison(
          records,
          includeIdentifiers: true,
          includeLabels: true,
        ).csv,
      );
      await tap(tester, find.text('Share reviewed files'));
      expect(share.export!.csv, preview.text);
      expect(share.export!.summary, contains('Second private room'));
      expect(
        find.text('Sharing cancelled. Nothing confirmed sent.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Share again'));
      expect(share.calls, 2);
    },
  );
  testWidgets(
    'busy blocks duplicate actions; failure recovery and unknown outcome honest',
    (tester) async {
      share.reply = Completer();
      await show(tester);
      await tap(tester, find.text('Share reviewed files'));
      expect(find.text('Opening share chooser…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).first)
            .onChanged,
        isNull,
      );
      share.reply!.completeError(StateError('Secret native error'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open sharing.'), findsOneWidget);
      expect(find.textContaining('Secret native error'), findsNothing);
      share.reply = null;
      share.result = ComparisonShareResult.unavailable;
      await tap(tester, find.text('Share again'));
      expect(
        find.textContaining('Delivery is not confirmed. You can retry.'),
        findsOneWidget,
      );
      share.result = ComparisonShareResult.handedOff;
      await tap(tester, find.text('Share again'));
      expect(
        find.text('Handed to sharing app. Delivery is not confirmed.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('deleted snapshot blocks sharing; return stays reachable', (
    tester,
  ) async {
    await show(tester);
    container
        .read(comparisonSessionsProvider.notifier)
        .delete(records.first.id);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Saved selection changed or was deleted.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('Return to saved sessions').hitTestable(), findsOneWidget);
    expect(share.calls, 0);
  });
  testWidgets(
    'unsupported file sharing explains copy/return recovery and stops retry loop',
    (tester) async {
      share.result = ComparisonShareResult.unsupported;
      await show(tester);
      await tap(tester, find.text('Share reviewed files'));
      expect(
        find.textContaining('Review or copy preview text'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'late share reply after navigation disposal cannot update a new preview',
    (tester) async {
      share.reply = Completer();
      await show(tester);
      await tap(tester, find.text('Share reviewed files'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();
      share.reply!.complete(ComparisonShareResult.handedOff);
      await tester.pumpAndSettle();
      share.reply = null;
      await show(tester);
      expect(find.text('Share reviewed files'), findsOneWidget);
      expect(find.textContaining('Handed to sharing app.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'maximum export keeps controls reachable in narrow large-text themes and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = evidence();
      records = List.generate(
        24,
        (i) =>
            evidence(id: '$i', samples: List.filled(120, source.samples.first)),
      );
      // Use loaded immutable snapshots, as production preview does.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          comparisonSessionsRepositoryProvider.overrideWithValue(
            MemorySessions()..saved = records,
          ),
          comparisonShareRepositoryProvider.overrideWithValue(share),
        ],
      );
      await container.read(comparisonSessionsProvider.notifier).ready;
      for (final dark in [false, true]) {
        for (final reduced in [false, true]) {
          await show(tester, dark: dark, scale: 2, reduced: reduced);
          expect(
            find.text('Share reviewed files').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.text('Return to saved sessions').hitTestable(),
            findsOneWidget,
          );
          await tap(tester, find.text('CSV preview'));
          await tester.ensureVisible(find.byTooltip('Next preview part'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Preview part 1 of'), findsOneWidget);
          await tap(tester, find.byTooltip('Next preview part'));
          expect(find.textContaining('Preview part 2 of'), findsOneWidget);
          expect(
            find.text('Share reviewed files').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
    },
  );
  testWidgets(
    'short narrow phone keeps return reachable after failure and deletion at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      share.fail = true;
      await show(tester, scale: 2);
      await tap(tester, find.text('Share reviewed files'));
      container
          .read(comparisonSessionsProvider.notifier)
          .delete(records.first.id);
      await tester.pumpAndSettle();
      expect(
        find.text('Return to saved sessions').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('delete during async file preparation prevents native chooser', (
    tester,
  ) async {
    final prepared = Completer<List<XFile>>();
    var calls = 0;
    container.dispose();
    container = ProviderContainer(
      overrides: [
        comparisonSessionsRepositoryProvider.overrideWithValue(
          MemorySessions()..saved = records,
        ),
        comparisonShareRepositoryProvider.overrideWithValue(
          PlatformComparisonShareRepository(
            supported: true,
            prepareFiles: (_) => prepared.future,
            shareFiles: (_) async {
              calls++;
              return ShareResult.unavailable;
            },
          ),
        ),
      ],
    );
    await container.read(comparisonSessionsProvider.notifier).ready;
    await show(tester);
    await tap(tester, find.text('Share reviewed files'));
    container
        .read(comparisonSessionsProvider.notifier)
        .delete(records.first.id);
    prepared.complete([]);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  testWidgets('desktop keyboard focus can activate sharing', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    // Focus native Material action through traversal, then activate via Enter.
    for (var i = 0; i < 12 && share.calls == 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      if (focused?.context != null &&
          focused!.context!.findAncestorWidgetOfExactType<FilledButton>() ==
              button) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
    }
    expect(share.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
