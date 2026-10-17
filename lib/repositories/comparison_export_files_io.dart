import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../models/comparison_export.dart';

bool get fileShareSupported => !Platform.isLinux;

/// Handed-off files remain usable for 24 hours. Cleanup runs at startup, before
/// another share, and on explicit request. OS/receivers may keep separate copies.
const comparisonExportRetention = Duration(hours: 24);
const maxRetainedComparisonExports = 16;

Future<Directory> _exportCache() async {
  final cache = await getTemporaryDirectory();
  return Directory('${cache.path}/wave_comparison_export')
      .create(recursive: true);
}

Future<void> cleanupComparisonFiles({
  bool clearAll = false,
  DateTime? now,
}) async {
  final directory = await _exportCache();
  final cutoff = (now ?? DateTime.now()).subtract(comparisonExportRetention);
  await _cleanupPluginCopies(clearAll: clearAll, cutoff: cutoff);
  await for (final entry in directory.list(followLinks: false)) {
    // Fixed files are from older releases, never active operations in this one.
    if (entry is File &&
        (entry.uri.pathSegments.last == ComparisonExport.summaryFilename ||
            entry.uri.pathSegments.last == ComparisonExport.csvFilename)) {
      await entry.delete();
    } else if (entry is Directory &&
        entry.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .startsWith('share-')) {
      if (clearAll || (await entry.stat()).modified.isBefore(cutoff)) {
        await entry.delete(recursive: true);
      }
    }
  }
}

Future<void> deleteComparisonFiles(
  List<XFile> files, {
  bool clearPluginCopies = false,
}) async {
  if (files.isEmpty) return;
  final parent = File(files.first.path).parent;
  final name =
      parent.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
  if (!name.startsWith('share-')) return;
  final root = await _exportCache();
  // Never delete caller-supplied files or recipient caches.
  if (parent.parent.path == root.path &&
      parent.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last
          .startsWith('share-') &&
      await parent.exists()) {
    await parent.delete(recursive: true);
    if (clearPluginCopies) await _cleanupPluginCopies(clearAll: true);
  }
}

// share_plus Android copies these exact neutral filenames into its private
// cache. Delete only Wave's two filenames, never arbitrary plugin files.
Future<void> _cleanupPluginCopies({
  required bool clearAll,
  DateTime? cutoff,
}) async {
  final cache = await getTemporaryDirectory();
  for (final name in [
    ComparisonExport.summaryFilename,
    ComparisonExport.csvFilename,
  ]) {
    final file = File('${cache.path}/share_plus/$name');
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    if (clearAll ||
        (cutoff != null && (await file.stat()).modified.isBefore(cutoff))) {
      await file.delete();
    }
  }
}

Future<List<XFile>> prepareComparisonFiles(ComparisonExport export) async {
  await cleanupComparisonFiles();
  final root = await _exportCache();
  final retained = await root
      .list(followLinks: false)
      .where((e) => e is Directory)
      .length;
  if (retained >= maxRetainedComparisonExports) {
    throw StateError(
      'Temporary exports full. Clear temporary exports in Settings or retry after retention expires.',
    );
  }
  final directory = await root.createTemp('share-');
  try {
    final summary = File(
      '${directory.path}/${ComparisonExport.summaryFilename}',
    );
    final csv = File('${directory.path}/${ComparisonExport.csvFilename}');
    await summary.writeAsString(export.summary, flush: true);
    await csv.writeAsString(export.csv, flush: true);
    return [
      XFile(summary.path, mimeType: 'text/plain'),
      XFile(csv.path, mimeType: 'text/csv'),
    ];
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

/// A new owned subdirectory avoids overwriting existing files in the chosen
/// folder. Cancellation/deleted selections remove only this operation's files.
Future<bool> saveComparisonFiles(
  ComparisonExport export, {
  bool Function()? isCurrent,
  Future<String?> Function()? chooseDirectory,
}) async {
  if (isCurrent != null && !isCurrent()) return false;
  final selected =
      await (chooseDirectory ??
          () => getDirectoryPath(confirmButtonText: 'Save reviewed files'))();
  if (selected == null || (isCurrent != null && !isCurrent())) return false;
  final directory = await Directory(selected).createTemp('wave-comparison-');
  var saved = false;
  try {
    if (isCurrent != null && !isCurrent()) return false;
    await File('${directory.path}/${ComparisonExport.summaryFilename}')
        .writeAsString(export.summary, flush: true);
    if (isCurrent != null && !isCurrent()) return false;
    await File('${directory.path}/${ComparisonExport.csvFilename}')
        .writeAsString(export.csv, flush: true);
    if (isCurrent != null && !isCurrent()) return false;
    saved = true;
    return true;
  } finally {
    if (!saved) await directory.delete(recursive: true);
  }
}
