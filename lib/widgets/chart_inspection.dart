import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chart_coordinates.dart';

/// Horizontal drag joins the gesture arena; vertical gestures remain page scroll.
/// Readout lives outside the plot so it stays readable at every cursor edge.
class ChartInspection extends StatefulWidget {
  const ChartInspection({
    super.key,
    required this.coordinates,
    required this.time,
    required this.height,
    required this.child,
    this.onEscape,
    this.hiddenBssids = const {},
  });
  final ChartCoordinates coordinates;
  final bool time;
  final double height;
  final Widget child;
  final VoidCallback? onEscape;
  final Set<String> hiddenBssids;
  @override
  State<ChartInspection> createState() => _ChartInspectionState();
}

class _ChartInspectionState extends State<ChartInspection> {
  Offset? _cursor;
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChartInspection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.time != oldWidget.time ||
        widget.coordinates.band != oldWidget.coordinates.band) {
      _cursor = null;
    }
  }

  void _inspect(Offset position, Size size) {
    final area = ChartCoordinates.area(size);
    if (area.width <= 0 || area.height <= 0) return;
    setState(
      () => _cursor = Offset(
        ((position.dx - area.left) / area.width).clamp(0, 1),
        ((position.dy - area.top) / area.height).clamp(0, 1),
      ),
    );
  }

  void _step(Offset delta) => setState(() {
    final next = (_cursor ?? const Offset(.5, .5)) + delta;
    _cursor = Offset(next.dx.clamp(0, 1), next.dy.clamp(0, 1));
  });
  void _dismiss() => setState(() => _cursor = null);
  String _readout(ChartHit hit) {
    final identity = '${hit.point.name} (${hit.point.bssid})';
    if (hit.sample case final sample?) {
      final at = sample.at
          .toIso8601String()
          .replaceFirst('T', ' ')
          .split('.')
          .first;
      final clipped = sample.rssi < -100 || sample.rssi > -20
          ? ' • marker clipped to axis'
          : '';
      return 'Recorded sample: $identity · $at · ${sample.rssi} dBm$clipped';
    }
    return 'Envelope: $identity · ${widget.coordinates.spectrumLabel(hit.fraction.dx)} · ${hit.rssi.toStringAsFixed(1)} dBm (illustrative)';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final plot = ChartCoordinates.area(
        Size(constraints.maxWidth, widget.height),
      );
      final hit = _cursor == null
          ? null
          : widget.coordinates.inspect(
              _cursor!,
              plot.size,
              timeGraph: widget.time,
              hiddenBssids: widget.hiddenBssids,
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _step(const Offset(-.01, 0)),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _step(const Offset(.01, 0)),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _step(const Offset(0, -.025)),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _step(const Offset(0, .025)),
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onEscape ?? _dismiss,
            },
            child: Focus(
              focusNode: _focus,
              child: Semantics(
                label: 'Inspect visible chart data. Drag horizontally, tap, or focus and use arrow keys. Marker follows curves; history selects recorded samples.',
                child: SizedBox(
                  height: widget.height,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, widget.height);
                      final area = ChartCoordinates.area(size);
                      return MouseRegion(
                        cursor: SystemMouseCursors.precise,
                        onHover: (event) => _inspect(event.localPosition, size),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (event) {
                            _focus.requestFocus();
                            _inspect(event.localPosition, size);
                          },
                          onHorizontalDragStart: (event) =>
                              _inspect(event.localPosition, size),
                          onHorizontalDragUpdate: (event) =>
                              _inspect(event.localPosition, size),
                          child: Stack(
                            children: [
                              Positioned.fill(child: widget.child),
                              if (hit != null &&
                                  area.width > 0 &&
                                  area.height > 0)
                                Positioned.fromRect(
                                  rect: area,
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      foregroundPainter: _Crosshair(
                                        hit.fraction,
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    hit != null
                        ? _readout(hit)
                        : _cursor == null
                        ? 'Drag sideways to follow curves • tap or use arrow keys'
                        : 'No visible ${widget.time ? 'history samples' : 'curves'}. Include a network in the legend.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (_cursor != null)
                IconButton(
                  tooltip: 'Dismiss inspection',
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          Text(
            widget.time
                ? 'Snaps to recorded observations • never interpolates missing samples.'
                : 'Marker follows illustrative envelopes • not an RF measurement.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}

class _Crosshair extends CustomPainter {
  const _Crosshair(this.cursor, this.color);
  final Offset cursor;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final x = cursor.dx * size.width, y = cursor.dy * size.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawCircle(Offset(x, y), 4, paint);
  }

  @override
  bool shouldRepaint(_Crosshair oldDelegate) =>
      cursor != oldDelegate.cursor || color != oldDelegate.color;
}
