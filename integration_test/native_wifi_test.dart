import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wifi_analyser/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android scan bridge returns real platform state', (
    tester,
  ) async {
    const native = MethodChannel('com.samirpandey.wifi_analyser/wifi');
    final snapshot = await native.invokeMapMethod<String, dynamic>('snapshot');
    expect(snapshot, isNotNull);
    expect(snapshot!['permission'], isA<bool>());
    expect(snapshot['wifiEnabled'], isA<bool>());
    expect(snapshot['locationEnabled'], isA<bool>());
    expect(snapshot['accessPoints'], isA<List>());

    await tester.pumpWidget(const ProviderScope(child: WaveApp()));
    await tester.pumpAndSettle();
    expect(find.text('Know your WiFi.'), findsOneWidget);
    expect(find.text('SIMULATED CONNECTION'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaveApp)),
    );
    await container
        .read(analyserProvider.notifier)
        .scan(requestPermission: false);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(analyserProvider).demo, isFalse);
    expect(container.read(analyserProvider).status, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
