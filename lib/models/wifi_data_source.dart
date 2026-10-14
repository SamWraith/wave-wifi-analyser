/// Explicit origin of observations; never inferred from identifiers or hardware.
enum WifiDataSource {
  demo,
  android,
  macos;

  String get label => switch (this) {
    demo => 'Demo',
    android => 'Android',
    macos => 'macOS',
  };

  String get evidenceLabel => switch (this) {
    demo => 'SIMULATED DEMO — not measured',
    android => 'MEASURED Android observations',
    macos => 'macOS scan observations — radio freshness unknown',
  };

  String get observationLimitations => switch (this) {
    demo => 'Simulated values are not measured WiFi evidence.',
    android => 'Samples require accepted fresh Android radio timestamps.',
    macos =>
      'Times mark accepted scan completion, not radio measurement time. '
          'CoreWLAN provides no per-network observation timestamp or reliable '
          'cache age; repeated results may contain cached radio observations.',
  };

  static WifiDataSource fromDemo(bool demo) =>
      demo ? WifiDataSource.demo : WifiDataSource.android;
}
