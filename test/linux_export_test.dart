import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/comparison_export.dart';
import 'package:wifi_analyser/repositories/comparison_export_files_io.dart';
import 'package:wifi_analyser/repositories/comparison_sessions_repository.dart';
import 'package:wifi_analyser/repositories/comparison_share_repository.dart';
import 'package:wifi_analyser/viewmodels/comparison_sessions_view_model.dart';
import 'package:wifi_analyser/views/comparison_export_page.dart';

import 'comparison_export_test.dart' show evidence;
import 'comparison_sessions_test.dart' show MemorySessions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const export = ComparisonExport(
    summary: 'Reviewed summary',
    csv: 'Reviewed CSV',
  );

  test(
    'save exports exact reviewed bytes without overwriting selected folder',
    () async {
      final root = await Directory.systemTemp.createTemp('wave-export-test-');
      addTearDown(() => root.delete(recursive: true));
      final existing = File('${root.path}/${ComparisonExport.summaryFilename}');
      await existing.writeAsString('Existing content');
      Future<String?> choose() async => root.path;
      expect(
        await saveComparisonFiles(export, chooseDirectory: choose),
        isTrue,
      );
      expect(
        await saveComparisonFiles(export, chooseDirectory: choose),
        isTrue,
      );
      expect(await existing.readAsString(), 'Existing content');
      final folders = await root
          .list()
          .where((entry) => entry is Directory)
          .toList();
      expect(folders, hasLength(2));
      for (final folder in folders) {
        expect(
          await File('${folder.path}/${ComparisonExport.summaryFilename}')
              .readAsString(),
          export.summary,
        );
        expect(
          await File('${folder.path}/${ComparisonExport.csvFilename}')
              .readAsString(),
          export.csv,
        );
      }
    },
  );

  test('cancelled or stale selection writes no export files', () async {
    final root = await Directory.systemTemp.createTemp(
      'wave-cancel-export-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    expect(
      await saveComparisonFiles(export, chooseDirectory: () async => null),
      isFalse,
    );
    var current = true;
    final choice = Completer<String?>();
    final pending = saveComparisonFiles(
      export,
      chooseDirectory: () => choice.future,
      isCurrent: () => current,
    );
    current = false;
    choice.complete(root.path);
    expect(await pending, isFalse);
    expect(await root.list().isEmpty, isTrue);
    // Invalidating after the owned directory exists cleans up that directory.
    var checks = 0;
    expect(
      await saveComparisonFiles(
        export,
        chooseDirectory: () async => root.path,
        isCurrent: () => ++checks < 4,
      ),
      isFalse,
    );
    expect(await root.list().isEmpty, isTrue);
  });

  test(
    'Linux save serializes chooser, recovers cancellation and write failure',
    () async {
      final reply = Completer<bool>();
      var calls = 0;
      final repository = LinuxComparisonExportRepository(
        saveFiles: (value, {isCurrent}) async {
          expect(value, same(export));
          calls++;
          if (calls == 1) return reply.future;
          if (calls == 2) throw const FileSystemException('denied');
          return true;
        },
      );
      final pending = repository.share(export, Rect.zero);
      await expectLater(repository.share(export, Rect.zero), throwsStateError);
      reply.complete(false);
      expect(await pending, ComparisonShareResult.cancelled);
      await expectLater(
        repository.share(export, Rect.zero),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await repository.share(export, Rect.zero),
        ComparisonShareResult.saved,
      );
    },
  );

  testWidgets(
    'Linux export names save action and reports local save/cancel honestly',
    (tester) async {
      final records = [evidence()];
      var saved = false;
      final container = ProviderContainer(
        overrides: [
          comparisonSessionsRepositoryProvider.overrideWithValue(
            MemorySessions()..saved = records,
          ),
          comparisonExportSavesFilesProvider.overrideWithValue(true),
          comparisonShareRepositoryProvider.overrideWithValue(
            LinuxComparisonExportRepository(
              saveFiles: (value, {isCurrent}) async {
                expect(value.summary, isNot(contains('Private WiFi')));
                expect(value.csv, isNot(contains('Private room')));
                return saved;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(comparisonSessionsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ComparisonExportPage(sessions: records)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share reviewed files'), findsNothing);
      await tester.tap(find.text('Save reviewed files'));
      await tester.pumpAndSettle();
      expect(find.text('Export cancelled. No files saved.'), findsOneWidget);
      saved = true;
      await tester.tap(find.text('Save again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No files uploaded.'), findsOneWidget);
      expect(find.textContaining('Handed to sharing app'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
