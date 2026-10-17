import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'repositories/comparison_export_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache failures must not prevent startup; the next share retries cleanup.
  try {
    await cleanupComparisonFiles();
  } catch (_) {}
  runApp(const ProviderScope(child: WaveApp()));
}
