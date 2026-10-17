import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../models/comparison_export.dart';

bool get fileShareSupported => true;
Future<List<XFile>> prepareComparisonFiles(ComparisonExport export) async => [
  XFile.fromData(utf8.encode(export.summary), mimeType: 'text/plain'),
  XFile.fromData(utf8.encode(export.csv), mimeType: 'text/csv'),
];

Future<bool> saveComparisonFiles(
  ComparisonExport export, {
  bool Function()? isCurrent,
  Future<String?> Function()? chooseDirectory,
}) async => false;

Future<void> cleanupComparisonFiles({
  bool clearAll = false,
  DateTime? now,
}) async {}
Future<void> deleteComparisonFiles(
  List<XFile> files, {
  bool clearPluginCopies = false,
}) async {}
