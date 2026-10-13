import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/ap_preference.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import '../viewmodels/analyser_view_model.dart';

final accessPointsProvider = Provider<List<AccessPoint>>(
  (ref) => ref.watch(analyserProvider.select((state) => state.accessPoints)),
);
final bandPointsProvider = Provider<List<AccessPoint>>((ref) {
  final points = ref.watch(accessPointsProvider);
  final band = ref.watch(analyserProvider.select((state) => state.band));
  return List.unmodifiable(
    points.where((ap) => ap.band == band).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi)),
  );
});
final visiblePointsProvider = Provider<List<AccessPoint>>((ref) {
  final points = ref.watch(bandPointsProvider);
  final (minimum, query) = ref.watch(
    analyserProvider.select((state) => (state.minimumRssi, state.query)),
  );
  final normalized = query.toLowerCase();
  final preferences = ref.watch(
    apPreferencesProvider.select((state) => state.entries),
  );
  return List.unmodifiable(
    points.where(
      (ap) =>
          ap.rssi >= minimum &&
          (ap.name.toLowerCase().contains(normalized) ||
              (preferences[preferenceKey(ap.bssid)]?.alias
                      ?.toLowerCase()
                      .contains(normalized) ??
                  false) ||
              ap.bssid.toLowerCase().contains(normalized)),
    ),
  );
});
final connectedPointProvider = Provider<AccessPoint?>(
  (ref) =>
      ref.watch(accessPointsProvider).where((ap) => ap.connected).firstOrNull,
);
final channelRatingsProvider = Provider<List<ChannelRating>>((ref) {
  final points = ref.watch(accessPointsProvider);
  final (band, exclude) = ref.watch(
    analyserProvider.select((state) => (state.band, state.excludeConnected)),
  );
  return List.unmodifiable(
    rateChannels(points, band, excludeConnected: exclude),
  );
});
