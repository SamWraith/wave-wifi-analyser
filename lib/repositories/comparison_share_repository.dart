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
    Future<void> Function(List<XFile>, {bool clearPluginCopies})? deleteFiles,
    bool? supported,
  }) : _shareFiles = shareFiles ?? SharePlus.instance.share,
       _prepareFiles = prepareFiles ?? prepareComparisonFiles,
       _deleteFiles = deleteFiles ?? deleteComparisonFiles,
       _supported = supported ?? fileShareSupported;
  final Future<ShareResult> Function(ShareParams) _shareFiles;
  final Future<List<XFile>> Function(ComparisonExport) _prepareFiles;
  final Future<void> Function(List<XFile>, {bool clearPluginCopies})
  _deleteFiles;
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
    if (isCurrent != null && !isCurrent()) {
      return ComparisonShareResult.cancelled;
    }
    _sharing = true;
    List<XFile>? files;
    var mayBeInUse = false;
    var dismissed = false;
    try {
      files = await _prepareFiles(export);
      if (isCurrent != null && !isCurrent()) {
        return ComparisonShareResult.cancelled;
      }
      // Unknown outcomes and exceptions after native handoff may still have a
      // receiver reading the files. Keep those until bounded cache cleanup.
      mayBeInUse = true;
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
      dismissed = result.status == ShareResultStatus.dismissed;
      if (dismissed) mayBeInUse = false;
      return switch (result.status) {
        ShareResultStatus.success => ComparisonShareResult.handedOff,
        ShareResultStatus.dismissed => ComparisonShareResult.cancelled,
        ShareResultStatus.unavailable => ComparisonShareResult.unavailable,
      };
    } finally {
      try {
        if (!mayBeInUse && files != null) {
          await _deleteFiles(files, clearPluginCopies: dismissed);
        }
      } finally {
        _sharing = false;
      }
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
