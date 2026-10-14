import 'package:flutter/material.dart';

import 'wave_motion.dart';

class WavePanel extends StatelessWidget {
  const WavePanel({super.key, required this.child, this.padding, this.color});
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding ?? const EdgeInsets.all(22), child: child),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.wifi_find_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class InsightTile extends StatelessWidget {
  const InsightTile({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.accent,
  });
  final IconData icon;
  final String title, text;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 20,
        color: accent ?? Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      WaveValue(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFEAE8FF), fontSize: 12),
      ),
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    this.accent,
  });
  final String label, value, note;
  final IconData icon;
  final Color? accent;
  @override
  Widget build(BuildContext context) => WavePanel(
    color: Color.alphaBlend(
      (accent ?? Theme.of(context).colorScheme.primary).withValues(alpha: .05),
      Theme.of(context).colorScheme.surface,
    ),
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (accent ?? Theme.of(context).colorScheme.primary).withValues(
              alpha: .12,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: accent ?? Theme.of(context).colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              WaveValue(value, style: Theme.of(context).textTheme.titleLarge),
              Text(
                note,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ResponsivePair extends StatelessWidget {
  const ResponsivePair({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 760,
    this.spacing = 18,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });
  final Widget first, second;
  final double breakpoint, spacing;
  final int firstFlex, secondFlex;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => bounds.maxWidth < breakpoint
        ? Column(
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: firstFlex, child: first),
              SizedBox(width: spacing),
              Expanded(flex: secondFlex, child: second),
            ],
          ),
  );
}
