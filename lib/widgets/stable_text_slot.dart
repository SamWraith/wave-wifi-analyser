import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reserves the largest known copy height without rendering hidden semantics.
/// Measurements follow available width, locale, text scale and actual styling.
class StableTextSlot extends StatelessWidget {
  const StableTextSlot({
    super.key,
    required this.text,
    required this.alternatives,
    required this.style,
  });
  final String text;
  final Iterable<String> alternatives;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      double height = 0;
      for (final value in {...alternatives, text}) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: resolved),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        height = math.max(height, painter.height);
        painter.dispose();
      }
      return SizedBox(
        height: height,
        child: Text(text, style: style),
      );
    },
  );
}
