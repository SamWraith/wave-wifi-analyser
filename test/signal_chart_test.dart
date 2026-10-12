import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/widgets/signal_charts.dart';
import 'package:wifi_analyser/widgets/spectrum_axis.dart';

AccessPoint point({int rssi = -50, int frequency = 5180, int width = 20}) =>
    AccessPoint(
      ssid: 'Network',
      bssid: '00:11:22:33:44:55',
      rssi: rssi,
      frequency: frequency,
      width: width,
    );

void main() {
  test(
    'spectrum retains ordinary band spacing and includes 4.9 GHz envelopes',
    () {
      final ordinary = SpectrumAxis.forPoints(WifiBand.ghz5, [point()]);
      expect(ordinary.minimum, 5150);
      expect(ordinary.maximum, 5850);
      final low = point(frequency: 4920, width: 40);
      final axis = SpectrumAxis.forPoints(WifiBand.ghz5, [low, point()]);
      expect(
        axis.fraction(low.spectralCenter - low.width / 2),
        greaterThanOrEqualTo(0),
      );
      expect(
        axis.fraction(low.spectralCenter + low.width / 2),
        lessThanOrEqualTo(1),
      );
      expect(axis.ticks, contains((184, 4920)));
      expect(axis.maximum, ordinary.maximum);
    },
  );

  testWidgets('equivalent chart content skips repaint; changed data repaints', (
    tester,
  ) async {
    Future<CustomPainter> render({
      List<AccessPoint>? points,
      WifiBand band = WifiBand.ghz5,
      ThemeData? theme,
      bool time = false,
      Map<String, List<SignalSample>>? history,
      Set<String> hiddenBssids = const {},
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? ThemeData.light(),
          home: Scaffold(
            body: SignalChart(
              points: points ?? [point()],
              band: band,
              time: time,
              history: history,
              hiddenBssids: hiddenBssids,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paint = find.descendant(
        of: find.byType(SignalChart),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(paint).width, greaterThan(0));
      expect(tester.takeException(), isNull);
      return tester.widget<CustomPaint>(paint).painter!;
    }

    final original = await render();
    expect((await render()).shouldRepaint(original), isFalse);
    expect(
      (await render(points: [point(rssi: -60)])).shouldRepaint(original),
      isTrue,
    );
    expect(
      (await render(points: [point(width: 80)])).shouldRepaint(original),
      isTrue,
    );
    expect(
      (await render(points: [point(frequency: 4920)])).shouldRepaint(original),
      isTrue,
    );
    expect((await render(band: WifiBand.ghz6)).shouldRepaint(original), isTrue);
    expect(
      (await render(theme: ThemeData.dark())).shouldRepaint(original),
      isTrue,
    );
    expect((await render(time: true)).shouldRepaint(original), isTrue);

    final hidden = {point().bssid};
    final hiddenPainter = await render(hiddenBssids: hidden);
    expect(hiddenPainter.shouldRepaint(original), isTrue);
    expect(
      (await render(hiddenBssids: {point().bssid}))
          .shouldRepaint(hiddenPainter),
      isFalse,
    );
    // Caller mutation cannot change the painter's frozen selection.
    hidden.clear();
    expect((await render()).shouldRepaint(hiddenPainter), isTrue);

    final at = DateTime(2026);
    final samples = [SignalSample(at, -50)];
    final history = {point().bssid: samples};
    final previous = await render(time: true, history: history);
    final equal = await render(
      time: true,
      history: {
        point().bssid: [SignalSample(at, -50)],
      },
    );
    expect(equal.shouldRepaint(previous), isFalse);
    // Caller mutation cannot change the old painter's captured history.
    samples.add(SignalSample(at.add(const Duration(seconds: 1)), -55));
    expect(
      (await render(time: true, history: history)).shouldRepaint(previous),
      isTrue,
    );
    final changedRssi = await render(
      time: true,
      history: {
        point().bssid: [SignalSample(at, -60)],
      },
    );
    expect(changedRssi.shouldRepaint(previous), isTrue);
    final changedTime = await render(
      time: true,
      history: {
        point().bssid: [SignalSample(at.add(const Duration(seconds: 1)), -50)],
      },
    );
    expect(changedTime.shouldRepaint(previous), isTrue);
  });
  testWidgets('hidden curves disappear from spectrum and history pixels', (
    tester,
  ) async {
    Future<List<int>> pixels({
      required bool time,
      required bool hidden,
      bool empty = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignalChart(
            points: empty ? [] : [point()],
            band: WifiBand.ghz5,
            time: time,
            hiddenBssids: hidden ? {point().bssid} : {},
            history: {
              point().bssid: [SignalSample(DateTime(2026), -50)],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paint = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(SignalChart),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      return (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        paint.paint(Canvas(recorder), const Size(300, 270));
        final picture = recorder.endRecording();
        final image = await picture.toImage(300, 270);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return data.buffer.asUint8List().toList();
        } finally {
          image.dispose();
          picture.dispose();
        }
      }))!;
    }

    for (final time in [false, true]) {
      final visible = await pixels(time: time, hidden: false);
      final hidden = await pixels(time: time, hidden: true);
      final empty = await pixels(time: time, hidden: false, empty: true);
      expect(listEquals(visible, hidden), isFalse);
      expect(listEquals(hidden, empty), isTrue);
    }
  });
}
