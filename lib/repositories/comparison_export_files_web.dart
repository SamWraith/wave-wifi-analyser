import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../models/comparison_export.dart';

bool get fileShareSupported => true;
Future<List<XFile>> prepareComparisonFiles(ComparisonExport export) async => [
  XFile.fromData(utf8.encode(export.summary), mimeType: 'text/plain'),
  XFile.fromData(utf8.encode(export.csv), mimeType: 'text/csv'),
];
