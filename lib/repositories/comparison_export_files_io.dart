import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
