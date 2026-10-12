import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'viewmodels/analyser_view_model.dart';
import 'views/analyser_home.dart';
import 'views/app_theme.dart';
import 'widgets/wave_motion.dart';

class WaveApp extends ConsumerWidget {
  const WaveApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      analyserProvider.select((state) => state.themeMode),
    );
    return MaterialApp(
      title: 'wave - wifi analyser',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      themeAnimationDuration: WaveMotion.duration(context, 360),
      themeAnimationCurve: Curves.easeInOutCubic,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const AnalyserHome(),
    );
  }
}
