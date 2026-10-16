import 'wifi_data_source.dart';

/// Freshness is elapsed observation time, never a promise of another scan.
const staleScanAge = Duration(minutes: 2);

bool isScanStale(DateTime? updated, DateTime now) =>
    updated == null || now.difference(updated) >= staleScanAge;

String scanAgeLabel(
  DateTime? updated,
  DateTime now, {
  required bool demo,
  WifiDataSource source = WifiDataSource.android,
}) {
  if (updated == null) {
    return source.usesCompletionTime && !demo
        ? 'No completed scan received yet'
        : 'No fresh result received yet';
  }
  final seconds = now.difference(updated).inSeconds.clamp(0, 1 << 31);
  final age = seconds < 60
      ? '${seconds}s ago'
      : seconds < 3600
      ? '${seconds ~/ 60}m ago'
      : '${seconds ~/ 3600}h ago';
  return '${demo
      ? 'Last simulated update'
      : source.usesCompletionTime
      ? 'Last completed scan'
      : 'Last fresh result'} $age';
}
