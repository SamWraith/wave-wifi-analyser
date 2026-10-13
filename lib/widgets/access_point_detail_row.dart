import 'package:flutter/material.dart';

/// Readable, selectable details adapt to narrow screens and larger text.
class AccessPointDetailRow extends StatelessWidget {
  const AccessPointDetailRow({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(13) > 20;
        final labelText = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        );
        final valueText = SelectableText(
          value,
          textAlign: stacked ? TextAlign.start : TextAlign.end,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelText, const SizedBox(height: 5), valueText],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: labelText),
                  const SizedBox(width: 16),
                  Expanded(child: valueText),
                ],
              );
      },
    ),
  );
}
