import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_analyser/models/access_point.dart';
import 'package:wifi_analyser/views/channels_page.dart';
import 'package:wifi_analyser/widgets/wave_motion.dart';

Widget harness(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('reveal finishes once and does not restart for data rebuilds', (
    tester,
  ) async {
    Widget page(String label) => harness(
      WaveReveal(key: const ValueKey('overview'), child: Text(label)),
    );
    await tester.pumpWidget(page('First scan'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page('Next scan'));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('Next scan'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion shows page and channel value immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const WaveReveal(child: Text('Ready')), reduced: true),
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(
      harness(
        const ChannelRatingTile(rating: ChannelRating(6, 2437, 1), amount: .8),
        reduced: true,
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .8,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('accessibility changes preserve focused page state', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Widget page(bool reduced) => harness(
      WaveReveal(
        key: const ValueKey('networks'),
        child: TextField(controller: controller, focusNode: focus),
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Home');
    final state = tester.state(find.byType(TextField));
    final selection = controller.selection;
    await tester.pumpWidget(page(true));
    expect(identical(state, tester.state(find.byType(TextField))), isTrue);
    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'Home');
    expect(controller.selection, selection);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(page(false));
    expect(identical(state, tester.state(find.byType(TextField))), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('press feedback cancels cleanly and keyboard activates once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        WaveInteractive(
          onTap: () => taps++,
          child: const Padding(
            padding: EdgeInsets.all(30),
            child: Text('Open network'),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Open network')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .985,
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel bars retarget smoothly then settle at measured amount', (
    tester,
  ) async {
    Widget bar(double amount) => harness(
      ChannelRatingTile(
        key: const ValueKey(6),
        rating: const ChannelRating(6, 2437, 1),
        amount: amount,
      ),
    );
    await tester.pumpWidget(bar(.8));
    await tester.pumpAndSettle();
    await tester.pumpWidget(bar(.2));
    await tester.pump(const Duration(milliseconds: 100));
    final value = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(value, greaterThan(.2));
    expect(value, lessThan(.8));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .2,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
