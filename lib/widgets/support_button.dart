import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/support_repository.dart';
import 'wave_haptics.dart';

/// A quiet, warm accent shared by the persistent toolbar and Settings.
class SupportButton extends ConsumerStatefulWidget {
  const SupportButton({super.key});

  @override
  ConsumerState<SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends ConsumerState<SupportButton> {
  bool _opening = false;

  Future<void> _openPage() async {
    if (_opening) return;
    setState(() => _opening = true);
    WaveHaptics.selection();
    var opened = false;
    try {
      opened = await ref.read(supportRepositoryProvider).openPage();
    } catch (_) {
      // Browser launch errors must not interrupt scanning or navigation.
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open your browser. Try again, or visit ${SupportRepository.page}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Optional support · opens Buy Me a Coffee in your browser',
      child: FilledButton.icon(
        onPressed: _opening ? null : _openPage,
        style: FilledButton.styleFrom(
          backgroundColor: dark
              ? const Color(0xFFF0CA86)
              : const Color(0xFFF6DFB5),
          foregroundColor: const Color(0xFF3B2A12),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
          side: BorderSide(
            color: dark ? const Color(0xFFE4B96C) : const Color(0xFFDDBB80),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.coffee_rounded, size: 20),
        label: Text(_opening ? 'Opening browser…' : 'Buy me a coffee'),
      ),
    );
  }
}

/// Lives outside the page scroller, so support stays visible on every tab.
class SupportBar extends StatelessWidget {
  const SupportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final showMessage =
                bounds.maxWidth >= 640 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20;
            return Row(
              children: [
                if (showMessage) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Independent app. Supported by you.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Always optional. Every feature stays free.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const SupportButton(),
                ] else
                  const Expanded(child: SupportButton()),
              ],
            );
          },
        ),
      ),
    );
  }
}
