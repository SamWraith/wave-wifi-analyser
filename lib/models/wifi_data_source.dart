/// Explicit origin of observations; never inferred from identifiers or hardware.
enum WifiDataSource {
  demo,
  android,
  macos,
  windows,
  linux;

  String get label => switch (this) {
    demo => 'Demo',
    android => 'Android',
    macos => 'macOS',
    windows => 'Windows',
    linux => 'Linux',
  };

  String get evidenceLabel => switch (this) {
    demo => 'SIMULATED DEMO — not measured',
    android => 'MEASURED Android observations',
    macos => 'macOS scan observations — radio freshness unknown',
    windows => 'Windows scan observations — radio freshness unknown',
    linux => 'Linux scan observations — radio freshness unknown',
  };

  String get observationLimitations => switch (this) {
    demo => 'Simulated values are not measured WiFi evidence.',
    android => 'Samples require accepted fresh Android radio timestamps.',
    macos =>
      'Times mark accepted scan completion, not radio measurement time. '
          'CoreWLAN provides no per-network observation timestamp or reliable '
          'cache age; repeated results may contain cached radio observations.',
    windows =>
      'Times mark accepted Windows scan completion, not radio measurement time. '
          'Driver cache may contribute. Per-AP freshness, channel width and '
          'center frequency are unavailable. Charts and channel overlap assume '
          '20 MHz for unknown widths; this is not reported RF metadata.',
    linux =>
      'Times mark accepted NetworkManager scan completion, not per-AP radio '
          'measurement time. RSSI comes from kernel nl80211 dBm reports; '
          'cached entries may contribute. Width and center frequency are unknown. '
          'Charts and channel overlap assume 20 MHz for unknown widths.',
  };

  /// Desktop completion IDs identify accepted scans, not per-AP radio age.
  bool get usesCompletionTime =>
      this == macos || this == windows || this == linux;

  static WifiDataSource fromDemo(bool demo) =>
      demo ? WifiDataSource.demo : WifiDataSource.android;
}
