import 'package:flutter/material.dart';

import '../widgets/wave_motion.dart';
import 'analyser_navigation.dart';
import 'channels_page.dart';
import 'networks_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'spectrum_page.dart';

class AnalyserHome extends StatefulWidget {
  const AnalyserHome({super.key});
  @override
  State<AnalyserHome> createState() => _AnalyserHomeState();
}

class _AnalyserHomeState extends State<AnalyserHome> {
  int selected = 0;
  final _scrollController = ScrollController();

  void _select(int value) {
    if (value == selected) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => selected = value);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) AnalyserSidebar(selected: selected, onSelected: _select),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.all(wide ? 32 : 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnalyserHeader(selected: selected, wide: wide),
                              const SizedBox(height: 22),
                              const ScanStatusBar(),
                              const SizedBox(height: 26),
                              if (selected != 4) ...[
                                const BandSelector(),
                                const SizedBox(height: 24),
                              ],
                              WaveReveal(
                                key: ValueKey(selected),
                                child: switch (selected) {
                                  0 => OverviewPage(
                                    onViewNetworks: () => _select(2),
                                  ),
                                  1 => const SpectrumPage(),
                                  2 => const NetworksPage(),
                                  3 => const ChannelsPage(),
                                  _ => const SettingsPage(),
                                },
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'WAVE  /  WIFI, MADE VISIBLE',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!wide)
                    NavigationBar(
                      selectedIndex: selected,
                      onDestinationSelected: _select,
                      destinations: List.generate(
                        pages.length,
                        (i) => NavigationDestination(
                          icon: Icon(pageIcons[i]),
                          label: pages[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
