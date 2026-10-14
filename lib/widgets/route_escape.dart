import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop Escape returns through the same route path as the visible back action.
class RouteEscape extends StatelessWidget {
  const RouteEscape({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
    },
    child: Focus(autofocus: true, child: child),
  );
}
