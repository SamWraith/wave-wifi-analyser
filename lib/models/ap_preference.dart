String preferenceKey(String bssid) => bssid.trim().toLowerCase();

/// Saved identity only. Never an observation or a signal-history sample.
class ApPreference {
  const ApPreference({
    required this.bssid,
    required this.ssid,
    this.alias,
    this.favorite = false,
  });
  final String bssid, ssid;
  final String? alias;
  final bool favorite;
  String get name => alias ?? (ssid.isEmpty ? 'Hidden network' : ssid);
  Map<String, Object?> toJson() => {
    'bssid': bssid,
    'ssid': ssid,
    'alias': alias,
    'favorite': favorite,
  };
}
