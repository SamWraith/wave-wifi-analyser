import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'viewmodels/analyser_view_model.dart';
import 'views/onboarding_gate.dart';
import 'viewmodels/onboarding_view_model.dart';
import 'views/app_theme.dart';
import 'widgets/wave_motion.dart';

class WaveApp extends ConsumerWidget {
  const WaveApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(
      onboardingProvider.select((state) => state.completed),
    );
    // Do not instantiate scanning or request Android permissions during welcome.
    final themeMode = completed
        ? ref.watch(analyserProvider.select((state) => state.themeMode))
        : ThemeMode.system;
    return MaterialApp(
      title: 'wave - wifi analyser',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      themeAnimationDuration: WaveMotion.duration(context, 360),
      themeAnimationCurve: Curves.easeInOutCubic,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const OnboardingGate(),
    );
  }
}
