import 'package:flutter/material.dart';

import 'support_button.dart';
import 'wave_components.dart';

class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) => WavePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: 'Support Wave',
          subtitle: 'A little support goes a long way.',
        ),
        const SizedBox(height: 16),
        Text(
          'Enjoying Wave? Buy me a coffee to support development. Choose your amount on Buy Me a Coffee. Always optional; every feature stays free.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const SupportButton(),
        const SizedBox(height: 8),
        Text(
          'Opens an external payment page in your browser.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
