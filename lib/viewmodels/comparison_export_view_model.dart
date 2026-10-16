import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comparison_export.dart';
import '../repositories/comparison_share_repository.dart';

class ComparisonExportState {
  const ComparisonExportState({
    this.busy = false,
    this.unsupported = false,
    this.message,
  });
  final bool busy, unsupported;
  final String? message;
}

final comparisonExportProvider =
    NotifierProvider.autoDispose<
      ComparisonExportViewModel,
      ComparisonExportState
    >(ComparisonExportViewModel.new);

class ComparisonExportViewModel extends Notifier<ComparisonExportState> {
  @override
  ComparisonExportState build() => const ComparisonExportState();

  Future<void> share(
    ComparisonExport export,
    Rect origin, {
    bool Function()? isCurrent,
  }) async {
    if (state.busy) return;
    final savesFiles = ref.read(comparisonExportSavesFilesProvider);
    state = const ComparisonExportState(busy: true);
    try {
      final result = await ref
          .read(comparisonShareRepositoryProvider)
          .share(
            export,
            origin,
            isCurrent: () => ref.mounted && (isCurrent?.call() ?? true),
          );
      if (!ref.mounted) return;
      state = ComparisonExportState(
        unsupported: result == ComparisonShareResult.unsupported,
        message: switch (result) {
          ComparisonShareResult.unsupported => 'File sharing is not supported on this platform. Review or copy preview text, or return to saved sessions.',
          ComparisonShareResult.handedOff =>
            'Handed to sharing app. Delivery is not confirmed.',
          ComparisonShareResult.saved => 'Saved reviewed summary and CSV in a new wave-comparison- folder inside your selected folder. No files uploaded.',
          ComparisonShareResult.cancelled =>
            savesFiles
                ? 'Export cancelled. No files saved.'
                : 'Sharing cancelled. Nothing confirmed sent.',
          ComparisonShareResult.unavailable => 'Share outcome unavailable on this platform. Delivery is not confirmed. You can retry.',
        },
      );
    } catch (_) {
      if (ref.mounted) {
        state = ComparisonExportState(
          message: savesFiles
              ? 'Could not save reviewed files. Check folder permissions and retry.'
              : 'Could not open sharing. No delivery confirmed. Retry sharing or return to saved sessions.',
        );
      }
    }
  }
}
