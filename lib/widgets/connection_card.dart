import 'package:flutter/material.dart';

import '../models/access_point.dart';
import 'wave_components.dart';

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.ap, required this.demo});
  final AccessPoint? ap;
  final bool demo;
  @override
  Widget build(BuildContext context) {
    final ap = this.ap;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7965DB), Color(0xFF4D469D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  demo
                      ? 'SIMULATED CONNECTION'
                      : ap != null
                      ? 'CONNECTED NETWORK'
                      : 'CONNECTION',
                  style: const TextStyle(
                    color: Color(0xFFEAE8FF),
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (ap != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ap.quality,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            ap?.name ?? 'Find your network',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            ap == null
                ? 'Run a scan. Connection identity may be unavailable or private.'
                : '${ap.band.label}  ·  ${ap.security}',
            style: const TextStyle(color: Color(0xFFEAE8FF), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              HeroStat(
                value: ap != null ? '${ap.rssi}' : '—',
                label: 'dBm • signal',
              ),
              HeroStat(
                value: ap != null ? '${ap.channel}' : '—',
                label: 'channel',
              ),
              HeroStat(
                value: ap != null && ap.width > 0 ? '${ap.width}' : '—',
                label: 'MHz • width',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
