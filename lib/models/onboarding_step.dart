import 'package:flutter/material.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.artboard,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    required this.icon,
  });
  final String artboard, eyebrow, title, body, action;
  final IconData icon;
  String get asset => 'assets/rive/wave_onboarding.riv';
}

const onboardingSteps = [
  OnboardingStep(
    artboard: 'Wave Signal',
    eyebrow: '01 / FIND YOUR SIGNAL',
    title: 'Meet your\nnetwork.',
    body: 'See nearby WiFi, understand signal strength, and find your connection in the crowd.',
    action: 'Explore the signal',
    icon: Icons.wifi_rounded,
  ),
  OnboardingStep(
    artboard: 'Wave Channels',
    eyebrow: '02 / MAKE ROOM',
    title: 'Less overlap.\nMore clarity.',
    body: 'Compare channel overlap and follow signal changes. Wave helps you find room for your network.',
    action: 'Compare channels',
    icon: Icons.stacked_line_chart_rounded,
  ),
  OnboardingStep(
    artboard: 'Wave Access',
    eyebrow: '03 / YOU’RE IN CONTROL',
    title: 'Ready when\nyou are.',
    body: 'Android needs precise location permission and Location services for nearby WiFi scans. Wave collects no location coordinates. Other platforms offer a labelled demo.',
    action: 'See scan access',
    icon: Icons.verified_user_rounded,
  ),
];
