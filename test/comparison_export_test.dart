import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wifi_analyser/repositories/comparison_export_files_io.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wifi_analyser/models/comparison_export.dart';
import 'package:wifi_analyser/models/comparison_session.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/comparison_share_repository.dart';

ComparisonSession evidence({
  String id = 'secret-id',
  String label = 'Private WiFi',
  String ssid = 'Private WiFi',
  String bssid = 'aa:bb:cc:dd:ee:ff',
  bool demo = false,
  WifiDataSource? source,
  List<SessionSample>? samples,
  bool saved = true,
}) => ComparisonSession(
  id: id,
  ssid: ssid,
  bssid: bssid,
  label: label,
  start: DateTime.utc(2026, 10, 13),
  end: saved ? DateTime.utc(2026, 10, 13, 0, 2) : null,
  demo: demo,
  source: source,
  reason: 'Private WiFi',
  cachedBatches: 2,
  missingBatches: 3,
  samples:
      samples ??
      [
        SessionSample(
          at: DateTime.utc(2026, 10, 13, 0, 0, 10, 123),
          rssi: -61,
          frequency: 5180,
          width: 80,
          centerFrequency: 5210,
        ),
        SessionSample(
          at: DateTime.utc(2026, 10, 13, 0, 1, 20),
          rssi: -49,
          frequency: 2412,
          width: 20,
        ),
      ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'default excludes identities, labels, internal IDs and arbitrary reasons',
    () {
      final export = serializeComparison([evidence()]);
      for (final text in [export.summary, export.csv]) {
        expect(text, isNot(contains('Private WiFi')));
        expect(text, isNot(contains('aa:bb:cc:dd:ee:ff')));
        expect(text, isNot(contains('secret-id')));
      }
      expect(export.csv.split('\r\n').first, isNot(contains('ssid')));
      expect(export.csv.split('\r\n').first, isNot(contains('room_label')));
    },
  );
  test('opt-ins independent; Unicode and CSV quote/newline cells survive', () {
    final s = evidence(label: '寝室, "north"\nDesk', ssid: '家庭📶');
    final labels = serializeComparison([s], includeLabels: true);
    expect(labels.csv, contains('"寝室, ""north""\nDesk"'));
    expect(labels.summary, contains(s.label));
    expect(labels.csv, isNot(contains(s.ssid)));
    final identities = serializeComparison([s], includeIdentifiers: true);
    expect(identities.csv, contains(s.ssid));
    expect(identities.summary, contains(s.bssid));
    expect(identities.csv, isNot(contains('寝室')));
  });
  test('CSV guards formula text after whitespace/control chars; RSSI stays numeric', () {
    for (final payload in [
      '=1+1',
      '+cmd',
      '-cmd',
      '@sum(1)',
      '  =1',
      '\t=1',
      '\r=1',
      '\n=1',
      '\u0000=1',
    ]) {
      final csv = serializeComparison(
        [evidence(label: payload, ssid: payload)],
        includeIdentifiers: true,
        includeLabels: true,
      ).csv;
      expect(csv, contains('"\'$payload"'));
      expect(csv, contains(',-61,5180,80,5210,'));
    }
  });
  test(
    'exact UTC sample fields, gaps and radio groups retained without inference',
    () {
      final export = serializeComparison([evidence()]);
      expect(export.csv, contains('2026-10-13T00:00:10.123Z'));
      expect(export.csv, contains(',-61,5180,80,5210,'));
      expect(export.csv, contains(',-49,2412,20,"",'));
      expect(export.summary, contains('Longest session gap: 69877.0 ms'));
      expect(
        export.summary,
        contains('wait to first: 10123.0 ms; silence to stop: 40000.0 ms'),
      );
      expect(export.summary, contains('median -61.0 dBm'));
      expect(export.summary, contains('median -49.0 dBm'));
      expect(export.summary, isNot(contains('median -55.0')));
      expect(export.summary, contains(exportLimitations));
      expect(export.summary, contains('MEASURED Android observations'));
    },
  );
  test('gap summary retains accepted sub-millisecond timestamp precision', () {
    final original = evidence();
    final export = serializeComparison([
      evidence(
        samples: [
          SessionSample(
            at: original.start.add(const Duration(microseconds: 123)),
            rssi: -50,
            frequency: 2412,
            width: 20,
          ),
        ],
      ),
    ]);
    expect(
      export.summary,
      contains('wait to first: 0.123 ms; silence to stop: 119999.877 ms'),
    );
    expect(export.csv, contains('2026-10-13T00:00:00.000123Z'));
  });
  test('empty simulated records carry metadata without invented sample', () {
    final export = serializeComparison([evidence(demo: true, samples: [])]);
    expect(export.summary, contains('SIMULATED DEMO — not measured'));
    expect(export.summary, contains('No fresh samples. No signal estimate.'));
    expect(export.csv.split('\r\n').length, 3);
    expect(export.csv, contains(',0,3,2,"","","","","","",'));
  });
  test('same SSID never merges distinct BSSIDs or sources; invalid inputs rejected', () {
    final s = evidence();
    for (final sessions in <List<ComparisonSession>>[
      [],
      [s, s],
      [s, evidence(id: 'other', bssid: 'bb')],
      [s, evidence(id: 'other', demo: true)],
      [s, evidence(id: 'mac', source: WifiDataSource.macos)],
      [evidence(saved: false)],
      List.generate(25, (i) => evidence(id: '$i')),
      [evidence(samples: List.filled(121, s.samples.first))],
    ]) {
      expect(() => serializeComparison(sessions), throwsArgumentError);
    }
    expect(
      serializeComparison([
        s,
        evidence(id: 'other', bssid: s.bssid.toUpperCase()),
      ]).summary,
      contains('Session 2'),
    );
  });
  test(
    'macOS export identifies completion times and unknown radio freshness',
    () {
      final export = serializeComparison([
        evidence(source: WifiDataSource.macos),
      ]);
      expect(
        export.summary,
        contains('macOS scan observations — radio freshness unknown'),
      );
      expect(
        export.summary,
        contains('accepted scan completion, not radio measurement time'),
      );
      expect(
        export.csv,
        contains('repeated results may contain cached radio observations'),
      );
      expect(export.summary, isNot(contains('MEASURED Android')));
      expect(export.csv, contains(',-61,5180,80,5210,'));
      expect(export.csv, isNot(contains('Private WiFi')));
      expect(
        serializeComparison([
          evidence(source: WifiDataSource.macos, samples: []),
        ]).summary,
        contains('No accepted scan observations. No signal estimate.'),
      );
    },
  );
  test('maximum bounded evidence serializes every accepted row', () {
    final samples = List.generate(
      120,
      (i) => SessionSample(
        at: DateTime.utc(2026, 10, 13, 0, 0, i),
        rssi: -i,
        frequency: 5180,
        width: 80,
      ),
    );
    final export = serializeComparison(
      List.generate(24, (i) => evidence(id: '$i', samples: samples)),
    );
    expect(export.csv.split('\r\n').length, 2882);
    expect(export.summary, contains('Session 24'));
  });
  test(
    'raw unknown/zero/explicit center contexts never pool summary medians',
    () {
      final s = evidence();
      final export = serializeComparison([
        evidence(
          samples: [
            SessionSample(at: s.start, rssi: -70, frequency: 5180, width: 80),
            SessionSample(
              at: s.start,
              rssi: -60,
              frequency: 5180,
              width: 80,
              centerFrequency: 0,
            ),
            SessionSample(
              at: s.start,
              rssi: -50,
              frequency: 5180,
              width: 80,
              centerFrequency: 5180,
            ),
          ],
        ),
      ]);
      expect(
        export.summary,
        contains('reported center unknown: 1 samples; median -70.0'),
      );
      expect(
        export.summary,
        contains('reported center 0 MHz: 1 samples; median -60.0'),
      );
      expect(
        export.summary,
        contains('reported center 5180 MHz: 1 samples; median -50.0'),
      );
    },
  );
  test(
    'owned source cache stays two files and overwrites previous opt-in content',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wave-export-test',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });
      final private = serializeComparison([
        evidence(),
      ], includeIdentifiers: true);
      final initial = await prepareComparisonFiles(private);
      final safe = serializeComparison([evidence()]);
      final current = await prepareComparisonFiles(safe);
      expect(current.map((f) => f.path), initial.map((f) => f.path));
      expect(await current.first.readAsString(), safe.summary);
      expect(await current.last.readAsString(), safe.csv);
      expect(
        await Directory('${directory.path}/wave_comparison_export')
            .list()
            .length,
        2,
      );
    },
  );
  test('navigation cancellation prevents late chooser and concurrent share is bounded', () async {
    final files = Completer<List<XFile>>();
    var current = true, called = false;
    final repo = PlatformComparisonShareRepository(
      prepareFiles: (_) => files.future,
      shareFiles: (_) async {
        called = true;
        return ShareResult.unavailable;
      },
    );
    final export = serializeComparison([evidence()]);
    final pending = repo.share(
      export,
      const Rect.fromLTWH(0, 0, 10, 10),
      isCurrent: () => current,
    );
    await expectLater(
      repo.share(export, const Rect.fromLTWH(0, 0, 10, 10)),
      throwsStateError,
    );
    current = false;
    files.complete([]);
    expect(await pending, ComparisonShareResult.cancelled);
    expect(called, isFalse);
  });
  test('unsupported platform does not prepare files or open chooser', () async {
    final repo = PlatformComparisonShareRepository(
      supported: false,
      prepareFiles: (_) async => throw StateError('must not prepare'),
      shareFiles: (_) async => throw StateError('must not share'),
    );
    expect(
      await repo.share(
        serializeComparison([evidence()]),
        const Rect.fromLTWH(0, 0, 10, 10),
      ),
      ComparisonShareResult.unsupported,
    );
  });
  test('platform receives exactly previewed files, neutral metadata and no web fallbacks', () async {
    final export = serializeComparison([evidence()]);
    ShareParams? captured;
    final repo = PlatformComparisonShareRepository(
      prepareFiles: (e) async => [
        XFile.fromData(utf8.encode(e.summary)),
        XFile.fromData(utf8.encode(e.csv)),
      ],
      shareFiles: (params) async {
        captured = params;
        return const ShareResult('', ShareResultStatus.dismissed);
      },
    );
    final result = await repo.share(
      export,
      const Rect.fromLTWH(10, 20, 100, 50),
    );
    expect(result, ComparisonShareResult.cancelled);
    expect(captured!.text, isNull);
    expect(captured!.subject, isNull);
    expect(captured!.title, 'Wave WiFi comparison');
    expect(captured!.downloadFallbackEnabled, isFalse);
    expect(captured!.mailToFallbackEnabled, isFalse);
    expect(captured!.fileNameOverrides, [
      'wave-comparison.txt',
      'wave-comparison.csv',
    ]);
    expect(
      utf8.decode(await captured!.files![0].readAsBytes()),
      export.summary,
    );
    expect(utf8.decode(await captured!.files![1].readAsBytes()), export.csv);
    expect(captured!.sharePositionOrigin, const Rect.fromLTWH(10, 20, 100, 50));
  });
  test(
    'platform result preserves handoff, cancellation and unknown outcome',
    () async {
      final export = serializeComparison([evidence()]);
      for (final status in ShareResultStatus.values) {
        final repo = PlatformComparisonShareRepository(
          prepareFiles: (e) async => [
            XFile.fromData(utf8.encode(e.summary)),
            XFile.fromData(utf8.encode(e.csv)),
          ],
          shareFiles: (_) async => ShareResult('', status),
        );
        expect(
          await repo.share(export, const Rect.fromLTWH(0, 0, 10, 10)),
          switch (status) {
            ShareResultStatus.success => ComparisonShareResult.handedOff,
            ShareResultStatus.dismissed => ComparisonShareResult.cancelled,
            ShareResultStatus.unavailable => ComparisonShareResult.unavailable,
          },
        );
      }
    },
  );
}
