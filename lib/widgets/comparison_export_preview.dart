import 'package:flutter/material.dart';

import 'wave_components.dart';
import 'wave_haptics.dart';

/// Exact contiguous text chunks; pagination bounds rendered text, not export.
class ComparisonExportPreview extends StatefulWidget {
  const ComparisonExportPreview({
    super.key,
    required this.text,
    this.csv = false,
  });
  final String text;
  final bool csv;
  @override
  State<ComparisonExportPreview> createState() =>
      _ComparisonExportPreviewState();
}

class _ComparisonExportPreviewState extends State<ComparisonExportPreview> {
  late List<String> _pages;
  int _page = 0;
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(ComparisonExportPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _page = 0;
      _split();
    }
  }

  void _split() {
    _pages = [];
    var start = 0;
    while (start < widget.text.length) {
      var end = (start + 6000).clamp(0, widget.text.length);
      if (end < widget.text.length) {
        final newline = widget.text.lastIndexOf('\n', end - 1);
        if (newline >= start) {
          end = newline + 1;
        } else if (widget.text.codeUnitAt(end) >= 0xdc00 &&
            widget.text.codeUnitAt(end) <= 0xdfff) {
          end--;
        }
      }
      _pages.add(widget.text.substring(start, end));
      start = end;
    }
    if (_pages.isEmpty) _pages.add('');
  }

  @override
  Widget build(BuildContext context) => WavePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Preview part ${_page + 1} of ${_pages.length}'),
            IconButton(
              tooltip: 'Previous preview part',
              onPressed: _page == 0
                  ? null
                  : () {
                      WaveHaptics.selection();
                      setState(() => _page--);
                    },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next preview part',
              onPressed: _page == _pages.length - 1
                  ? null
                  : () {
                      WaveHaptics.selection();
                      setState(() => _page++);
                    },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const Text(
          'All parts are included in the shared file. CSV parts continue from the previous part; header appears in part 1.',
        ),
        const SizedBox(height: 12),
        if (widget.csv) ...[
          Text(
            'Scroll horizontally to inspect CSV columns.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                _pages[_page],
                key: ValueKey((widget.text, _page)),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ] else
          SelectableText(_pages[_page], key: ValueKey((widget.text, _page))),
      ],
    ),
  );
}
