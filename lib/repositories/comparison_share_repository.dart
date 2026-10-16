import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/comparison_export.dart';
import 'comparison_export_files.dart';

enum ComparisonShareResult {
  handedOff,
  cancelled,
  unavailable,
  unsupported,
  saved,
}

abstract interface class ComparisonShareRepository {
  Future<ComparisonShareResult> share(
    ComparisonExport export,
    Rect origin, {
    bool Function()? isCurrent,
  });
}

/// Linux lacks native file sharing; its explicit action saves reviewed files.
final comparisonExportSavesFilesProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux,
);

final comparisonShareRepositoryProvider = Provider<ComparisonShareRepository>(
  (ref) => ref.read(comparisonExportSavesFilesProvider)
      ? LinuxComparisonExportRepository()
      : PlatformComparisonShareRepository(),
);

class PlatformComparisonShareRepository implements ComparisonShareRepository {
  PlatformComparisonShareRepository({
    Future<ShareResult> Function(ShareParams)? shareFiles,
    Future<List<XFile>> Function(ComparisonExport)? prepareFiles,
    bool? supported,
  }) : _shareFiles = shareFiles ?? SharePlus.instance.share,
       _prepareFiles = prepareFiles ?? prepareComparisonFiles,
       _supported = supported ?? fileShareSupported;
  final Future<ShareResult> Function(ShareParams) _shareFiles;
  final Future<List<XFile>> Function(ComparisonExport) _prepareFiles;
  final bool _supported;
  bool _sharing = false;
  @override
  Future<ComparisonShareResult> share(
    ComparisonExport export,
    Rect origin, {
    bool Function()? isCurrent,
  }) async {
    if (!_supported) return ComparisonShareResult.unsupported;
    if (_sharing) throw StateError('A share chooser is already pending.');
    _sharing = true;
    try {
      final files = await _prepareFiles(export);
      if (isCurrent != null && !isCurrent()) {
        return ComparisonShareResult.cancelled;
      }
      final result = await _shareFiles(
        ShareParams(
          title: 'Wave WiFi comparison',
          files: files,
          fileNameOverrides: [
            ComparisonExport.summaryFilename,
            ComparisonExport.csvFilename,
          ],
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ComparisonShareResult.handedOff,
        ShareResultStatus.dismissed => ComparisonShareResult.cancelled,
        ShareResultStatus.unavailable => ComparisonShareResult.unavailable,
      };
    } finally {
      _sharing = false;
    }
  }
}

class LinuxComparisonExportRepository implements ComparisonShareRepository {
  LinuxComparisonExportRepository({
    Future<bool> Function(ComparisonExport, {bool Function()? isCurrent})?
    saveFiles,
  }) : _saveFiles = saveFiles ?? saveComparisonFiles;
  final Future<bool> Function(ComparisonExport, {bool Function()? isCurrent})
  _saveFiles;
  bool _saving = false;

  @override
  Future<ComparisonShareResult> share(
    ComparisonExport export,
    Rect origin, {
    bool Function()? isCurrent,
  }) async {
    if (_saving) {
      throw StateError('An export folder chooser is already pending.');
    }
    _saving = true;
    try {
      return await _saveFiles(export, isCurrent: isCurrent)
          ? ComparisonShareResult.saved
          : ComparisonShareResult.cancelled;
    } finally {
      _saving = false;
    }
  }
}
