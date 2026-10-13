import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/models/channel_plan.dart';
import 'package:wifi_analyser/viewmodels/channel_planning_view_model.dart';

void main() {
  test('primary channels map to exceptional and bonded centers', () {
    expect(planningFrequency(WifiBand.ghz24, 14), 2484);
    expect(planningFrequency(WifiBand.ghz5, 184), 4920);
    expect(planningFrequency(WifiBand.ghz6, 2), 5935);
    expect(planningCenters(WifiBand.ghz24, 6, 40), [2427, 2447]);
    expect(planningCenters(WifiBand.ghz24, 14, 40), isEmpty);
    expect(planningCenters(WifiBand.ghz5, 184, 40), isEmpty);
    for (final primary in [36, 40, 44, 48]) {
      expect(planningCenters(WifiBand.ghz5, primary, 80), [5210]);
    }
    expect(planningCenters(WifiBand.ghz5, 64, 160), [5250]);
    expect(planningCenters(WifiBand.ghz5, 144, 160), isEmpty);
    expect(planningCenters(WifiBand.ghz5, 161, 80), [5775]);
    expect(planningCenters(WifiBand.ghz5, 177, 160), [5815]);
    expect(planningCenters(WifiBand.ghz6, 5, 80), [5985]);
    expect(planningCenters(WifiBand.ghz6, 29, 160), [6025]);
    expect(planningCenters(WifiBand.ghz6, 233, 40), isEmpty);
    expect(planningCenters(WifiBand.ghz6, 2, 80), isEmpty);
    expect(planningCenters(WifiBand.ghz6, 1, 320), isEmpty);
  });

  test('displayed defaults include only width-compatible scored examples', () {
    for (final band in WifiBand.values) {
      for (final width in planningWidths(band)) {
        final defaults = defaultPlanningChannels(band, width);
        final plans = planChannels([], band, PlanningAssumptions(width: width));
        expect(plans.map((p) => p.channel).toSet(), defaults.toSet());
      }
    }
    expect(defaultPlanningChannels(WifiBand.ghz6, 160), isNot(contains(229)));
  });

  test(
    'shortlist rejects invalid edits and merges duplicate ASCII entries',
    () {
      expect(parsePlanningChannels(' 36, 40 36,040 ', WifiBand.ghz5, 80), [
        36,
        40,
      ]);
      expect(parsePlanningChannels('  ', WifiBand.ghz5, 80), isEmpty);
      for (final input in [
        'abc',
        '３６',
        '-36',
        '36.0',
        '36;40',
        '36,42',
        ',36',
        '36,',
        '99999999999999999999999999',
      ]) {
        expect(
          () => parsePlanningChannels(input, WifiBand.ghz5, 80),
          throwsFormatException,
        );
      }
      expect(
        () => parsePlanningChannels('14', WifiBand.ghz24, 40),
        throwsFormatException,
      );
      expect(
        () => parsePlanningChannels(
          List.filled(65, '1').join(' '),
          WifiBand.ghz24,
          20,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'width changes score using reported centers, power and BSSID identity',
    () {
      const aps = [
        AccessPoint(
          ssid: 'Same',
          bssid: 'one',
          rssi: -50,
          frequency: 5180,
          width: 80,
          centerFrequency: 5210,
        ),
        AccessPoint(
          ssid: 'Same',
          bssid: 'two',
          rssi: -60,
          frequency: 5240,
          width: 20,
        ),
        AccessPoint(
          ssid: 'Other band',
          bssid: 'three',
          rssi: -20,
          frequency: 2412,
        ),
        AccessPoint(
          ssid: 'Connected',
          bssid: 'four',
          rssi: -20,
          frequency: 5180,
          connected: true,
        ),
      ];
      final narrow = planChannels(
        aps,
        WifiBand.ghz5,
        PlanningAssumptions(channels: [36]),
      ).single;
      final wide = planChannels(
        aps,
        WifiBand.ghz5,
        PlanningAssumptions(width: 80, channels: [36]),
      ).single;
      expect(narrow.score, closeTo(4, 0.00001));
      expect(wide.score, closeTo(10.4, 0.00001));
      expect(wide.contributors.map((c) => c.ap.bssid), ['one', 'two']);
      expect(identical(wide.contributors.first.ap, aps.first), isTrue);
      expect(aps.first.width, 80);
      expect(aps.first.centerFrequency, 5210);
      expect(
        planChannels(
          aps,
          WifiBand.ghz5,
          PlanningAssumptions(channels: [36]),
          excludeConnected: false,
        ).single.score,
        greaterThan(1000),
      );
      expect(() => wide.contributors.clear(), throwsUnsupportedError);
    },
  );

  test(
    'bounded reasons retain all contributor weight and deterministic order',
    () {
      final aps = List.generate(
        100,
        (i) => AccessPoint(
          ssid: 'Same',
          bssid: i.toString().padLeft(3, '0'),
          rssi: -60,
          frequency: 2412,
        ),
      );
      final plan = planChannels(
        aps,
        WifiBand.ghz24,
        PlanningAssumptions(channels: [1]),
      ).single;
      expect(plan.contributors.map((c) => c.ap.bssid), ['000', '001', '002']);
      expect(plan.contributorCount, 100);
      expect(plan.score, 100);
    },
  );

  test('overlap matches existing heuristic at 20 MHz and zero at edge', () {
    const ap = AccessPoint(ssid: 'x', bssid: 'x', rssi: -60, frequency: 2484);
    expect(overlapContribution(ap, 2464, 20), 0);
    expect(
      planChannels(
        [ap],
        WifiBand.ghz24,
        PlanningAssumptions(channels: [14]),
      ).single.score,
      1,
    );
    expect(
      overlapContribution(ap, 2474, 20),
      estimateChannelOverlap([ap], WifiBand.ghz24, 2474),
    );
    expect(
      planChannels(
        [],
        WifiBand.ghz24,
        PlanningAssumptions(),
      ).every((p) => p.score == 0),
      isTrue,
    );
  });

  test('applied edits are bounded immutable, band-specific and resettable', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final vm = container.read(planningAssumptionsProvider.notifier);
    vm.apply(WifiBand.ghz5, 80, '48,36,36');
    vm.apply(WifiBand.ghz24, 40, '6');
    final before = container.read(planningAssumptionsProvider);
    expect(before[WifiBand.ghz5]!.channels, [36, 48]);
    expect(() => before.clear(), throwsUnsupportedError);
    expect(
      () => before[WifiBand.ghz5]!.channels.clear(),
      throwsUnsupportedError,
    );
    expect(() => vm.apply(WifiBand.ghz5, 160, '144'), throwsFormatException);
    expect(
      identical(before, container.read(planningAssumptionsProvider)),
      isTrue,
    );
    vm.reset(WifiBand.ghz5);
    expect(
      container.read(planningAssumptionsProvider).containsKey(WifiBand.ghz5),
      isFalse,
    );
    expect(
      container.read(planningAssumptionsProvider)[WifiBand.ghz24]!.width,
      40,
    );
  });
}
