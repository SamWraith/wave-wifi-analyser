import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/models/wifi_data_source.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';

/// Runs on a Windows desktop, including hosts without WiFi hardware.
/// Permission granting and physical RF assertions belong to the hardware matrix.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows bridge exposes honest cached state and cancels safely', (
    tester,
  ) async {
    final repo = WindowsWifiRepository();
    final initial = await repo.snapshot();
    expect(initial.source, WifiDataSource.windows);
    expect(initial.scanCompleted, isFalse);
    expect(initial.fresh, isFalse);
    expect(initial.scanRequested, isFalse);
    for (final ap in initial.accessPoints) {
      expect(ap.timestamp, 0);
      expect(ap.width, 0);
      expect(ap.centerFrequency, isNull);
    }
    await repo.cancelScan();
    try {
      final scan = await repo.scan();
      expect(scan.source, WifiDataSource.windows);
      expect(scan.fresh, isFalse);
      expect(scan.scanRequested, isFalse);
      if (scan.scanCompleted) expect(scan.completionId, greaterThan(0));
    } on PlatformException catch (error) {
      // Native failures remain errors rather than simulated success.
      expect(error.code, isNotEmpty);
      expect(error.message, isNotEmpty);
    }
    await repo.cancelScan();
    expect((await repo.snapshot()).scanCompleted, isFalse);
  }, skip: kIsWeb || defaultTargetPlatform != TargetPlatform.windows);
}
