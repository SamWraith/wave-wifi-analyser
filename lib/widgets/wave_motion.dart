import 'package:flutter/material.dart';

/// Shared, finite motion that follows the device's accessibility preferences.
abstract final class WaveMotion {
  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return (media?.disableAnimations ?? features.disableAnimations) ||
        (media?.accessibleNavigation ?? features.accessibleNavigation);
  }

  static Duration duration(BuildContext context, [int milliseconds = 280]) =>
      reduced(context) ? Duration.zero : Duration(milliseconds: milliseconds);

  static AnimationStyle sheetStyle(BuildContext context) => AnimationStyle(
    duration: duration(context, 320),
    reverseDuration: duration(context, 220),
  );

  static const curve = Curves.easeOutCubic;
}

/// Key this by navigation intent, not by incoming scan results.
class WaveReveal extends StatelessWidget {
  const WaveReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = WaveMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: WaveMotion.duration(context),
      curve: WaveMotion.curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: reduced ? 1 : value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Displays exact measured values with a brief fade; never invents samples.
class WaveValue extends StatelessWidget {
  const WaveValue(this.value, {super.key, this.style});
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: WaveMotion.duration(context, 180),
    switchInCurve: WaveMotion.curve,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.centerLeft,
      children: [
        ...previous.map((child) => ExcludeSemantics(child: child)),
        ?current,
      ],
    ),
    child: Text(value, key: ValueKey(value), style: style),
  );
}

/// Pointer, keyboard and focus feedback for actionable surfaces.
class WaveInteractive extends StatefulWidget {
  const WaveInteractive({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final VoidCallback onTap;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<WaveInteractive> createState() => _WaveInteractiveState();
}

class _WaveInteractiveState extends State<WaveInteractive> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed && !WaveMotion.reduced(context) ? .985 : 1,
    duration: WaveMotion.duration(context, 120),
    curve: WaveMotion.curve,
    child: AnimatedContainer(
      duration: WaveMotion.duration(context, 140),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: Theme.of(context).colorScheme.primary
            .withValues(alpha: _hovered || _focused ? .07 : 0),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: widget.child,
        ),
      ),
    ),
  );
}
