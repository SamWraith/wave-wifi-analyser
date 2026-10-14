import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Feedback belongs to explicit user intent, never background scan updates.
abstract final class WaveHaptics {
  static const _native = MethodChannel('com.samirpandey.wifi_analyser/wifi');
  static bool get _macos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static void selection() {
    if (_supported) _send(HapticFeedback.selectionClick());
    if (_macos) {
      _send(_native.invokeMethod<void>('haptic', {'kind': 'selection'}));
    }
  }

  static void impact() {
    if (_supported) _send(HapticFeedback.lightImpact());
    if (_macos) _send(_native.invokeMethod<void>('haptic', {'kind': 'impact'}));
  }

  static Future<void> _send(Future<void> feedback) async {
    try {
      await feedback;
    } on PlatformException {
      // Optional device feedback must not block the requested action.
    } on MissingPluginException {
      // Some supported targets have no haptic hardware/plugin.
    }
  }
}
