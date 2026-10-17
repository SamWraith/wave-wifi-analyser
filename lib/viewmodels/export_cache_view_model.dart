import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/comparison_export_files.dart';

final exportCacheCleanupProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => cleanupComparisonFiles(clearAll: true),
);

class ExportCacheState {
  const ExportCacheState({this.busy = false, this.message});
  final bool busy;
  final String? message;
}

final exportCacheProvider =
    NotifierProvider.autoDispose<ExportCacheViewModel, ExportCacheState>(
      ExportCacheViewModel.new,
    );

class ExportCacheViewModel extends Notifier<ExportCacheState> {
  @override
  ExportCacheState build() => const ExportCacheState();

  Future<void> clear() async {
    if (state.busy) return;
    state = const ExportCacheState(busy: true);
    try {
      await ref.read(exportCacheCleanupProvider)();
      if (ref.mounted) {
        state = const ExportCacheState(message: 'Temporary exports cleared.');
      }
    } catch (_) {
      if (ref.mounted) {
        state = const ExportCacheState(
          message: 'Could not clear temporary exports. Retry.',
        );
      }
    }
  }
}
