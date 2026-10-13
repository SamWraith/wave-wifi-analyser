import 'dart:async';

import 'package:flutter/material.dart';

import '../models/scan_freshness.dart';

/// Presentation clock only: no measurement writes or background timer.
class ScanFreshness extends StatefulWidget {
  const ScanFreshness({
    super.key,
    required this.updated,
    required this.demo,
    this.cached = true,
    this.clock = DateTime.now,
  });
  final DateTime? updated;
  final bool demo, cached;
  final DateTime Function() clock;

  @override
  State<ScanFreshness> createState() => _ScanFreshnessState();
}

class _ScanFreshnessState extends State<ScanFreshness>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.updated == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = widget.clock());
    });
  }

  @override
  void didUpdateWidget(ScanFreshness oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = widget.clock();
    if (oldWidget.updated != widget.updated) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = widget.clock());
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        scanAgeLabel(widget.updated, _now, demo: widget.demo),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        widget.demo
            ? 'Demo data • no hardware measurement'
            : widget.cached
            ? 'Cached results • signal may have changed'
            : isScanStale(widget.updated, _now)
            ? 'Older observations • recheck before comparing'
            : 'Recent observations • Android controls scan availability',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
