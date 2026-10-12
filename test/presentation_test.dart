import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_analyser/app.dart';
import 'package:wifi_analyser/models/analyser_state.dart';
import 'package:wifi_analyser/repositories/wifi_repository.dart';
import 'package:wifi_analyser/viewmodels/analyser_view_model.dart';
import 'package:wifi_analyser/views/analyser_navigation.dart';
import 'package:wifi_analyser/views/analyser_providers.dart';
import 'package:wifi_analyser/views/channels_page.dart';
import 'package:wifi_analyser/views/settings_page.dart';
import 'package:wifi_analyser/widgets/network_tile.dart';

void main() {
  Future<ProviderContainer> start(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeDefaultProvider.overrideWithValue(true),
          wifiRepositoryProvider.overrideWithValue(_EmptyWifiRepository()),
        ],
        child: const WaveApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(WaveApp)));
  }

  testWidgets('signal updates preserve sidebar and settings build boundaries', (
    tester,
  ) async {
    final container = await start(tester);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final sidebarTile = find
        .descendant(
          of: find.byType(AnalyserSidebar),
          matching: find.byType(ListTile),
        )
        .first;
    final appearanceWrap = find.descendant(
      of: find.byType(AppearanceCard),
      matching: find.byType(Wrap),
    );
    final beforeSidebar = tester.widget(sidebarTile);
    final beforeAppearance = tester.widget(appearanceWrap);
    final beforePoints = container.read(accessPointsProvider);
    await container.read(analyserProvider.notifier).scan();
    await tester.pump();
    expect(
      identical(beforePoints, container.read(accessPointsProvider)),
      isFalse,
    );
    expect(identical(beforeSidebar, tester.widget(sidebarTile)), isTrue);
    expect(identical(beforeAppearance, tester.widget(appearanceWrap)), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'channel ratings ignore display query and normalize shared rows',
    (tester) async {
      final container = await start(tester);
      final vm = container.read(analyserProvider.notifier);
      final ratings = container.read(channelRatingsProvider);
      vm.setQuery('nothing matches');
      await tester.pump();
      expect(
        identical(ratings, container.read(channelRatingsProvider)),
        isTrue,
      );
      await tester.tap(find.text('Channels').last);
      await tester.pumpAndSettle();
      expect(find.byType(ChannelRatingTile), findsNWidgets(3));
      final amounts = tester
          .widgetList<ChannelRatingTile>(find.byType(ChannelRatingTile))
          .map((tile) => tile.amount)
          .toList();
      expect(amounts.every((value) => value >= 0 && value <= 1), isTrue);
      expect(amounts, contains(1.0));
      await tester.runAsync(() => vm.setDemo(false));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelRatingTile), findsNothing);
      expect(
        find.text('Scan this band before comparing channels.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reused network tile opens explicit access point details', (
    tester,
  ) async {
    await start(tester);
    final tile = find.byType(NetworkTile).first;
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AccessPointDetailsSheet), findsOneWidget);
    expect(find.text('Copy MAC address'), findsOneWidget);
    expect(find.text('A4:83:E7:12:80:4C'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _EmptyWifiRepository implements WifiRepository {
  @override
  bool get supported => false;
  @override
  Stream<WifiSnapshot> get scanResults => const Stream.empty();
  @override
  Future<WifiSnapshot> snapshot() async => WifiSnapshot(
    permission: false,
    locationEnabled: false,
    wifiEnabled: false,
    status: 'Unavailable',
    accessPoints: const [],
  );
  @override
  Future<WifiSnapshot> scan() => snapshot();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> openSettings() async {}
}
