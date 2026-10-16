import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../models/comparison_export.dart';

bool get fileShareSupported => !Platform.isLinux;

/// Two owned cache files, overwritten on explicit sharing only. Native share
/// services may retain their own copies; chooser completion is not delivery.
Future<List<XFile>> prepareComparisonFiles(ComparisonExport export) async {
  final cache = await getTemporaryDirectory();
  final directory = await Directory('${cache.path}/wave_comparison_export')
      .create(recursive: true);
  final summary = File('${directory.path}/${ComparisonExport.summaryFilename}');
  final csv = File('${directory.path}/${ComparisonExport.csvFilename}');
  await summary.writeAsString(export.summary, flush: true);
  await csv.writeAsString(export.csv, flush: true);
  return [
    XFile(summary.path, mimeType: 'text/plain'),
    XFile(csv.path, mimeType: 'text/csv'),
  ];
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
