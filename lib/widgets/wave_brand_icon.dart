import 'package:flutter/material.dart';

/// Uses the same generated Wave artwork as the platform launcher icons.
class WaveBrandIcon extends StatelessWidget {
  const WaveBrandIcon({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final appearance = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    return Image.asset(
      'assets/branding/wave-badge-$appearance.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
