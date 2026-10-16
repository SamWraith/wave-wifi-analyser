import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comparison_export.dart';
import '../models/comparison_session.dart';
import '../repositories/comparison_share_repository.dart';
import '../viewmodels/comparison_export_view_model.dart';
import '../viewmodels/comparison_sessions_view_model.dart';
import '../widgets/wave_components.dart';
import '../widgets/comparison_export_preview.dart';
import '../widgets/wave_haptics.dart';
import '../widgets/wave_motion.dart';
import '../widgets/route_escape.dart';

class ComparisonExportPage extends StatelessWidget {
  ComparisonExportPage({super.key, required List<ComparisonSession> sessions})
    : sessions = List.unmodifiable(sessions);
  final List<ComparisonSession> sessions;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      comparisonExportProvider.overrideWith(ComparisonExportViewModel.new),
    ],
    child: RouteEscape(child: _ComparisonExportContent(sessions: sessions)),
  );
}

class _ComparisonExportContent extends ConsumerStatefulWidget {
  const _ComparisonExportContent({required this.sessions});
  final List<ComparisonSession> sessions;
  @override
  ConsumerState<_ComparisonExportContent> createState() =>
      _ComparisonExportPageState();
}

class _ComparisonExportPageState
    extends ConsumerState<_ComparisonExportContent> {
  bool _identifiers = false, _labels = false, _csv = false;
  late ComparisonExport _export;
  @override
  void initState() {
    super.initState();
    _refreshExport();
  }

  void _refreshExport() {
    _export = serializeComparison(
      widget.sessions,
      includeIdentifiers: _identifiers,
      includeLabels: _labels,
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = ref.watch(
      comparisonSessionsProvider.select(
        (state) => widget.sessions.every(
          (snapshot) => state.sessions.any((s) => identical(s, snapshot)),
        ),
      ),
    );
    final sharing = ref.watch(comparisonExportProvider);
    final savesFiles = ref.watch(comparisonExportSavesFilesProvider);
    final export = _export;
    return Scaffold(
      appBar: AppBar(title: const Text('Review comparison export')),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!valid || sharing.message != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .2,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!valid)
                              Text(
                                savesFiles
                                    ? 'Saved selection changed or was deleted. Return to saved sessions and select again; this preview cannot be saved.'
                                    : 'Saved selection changed or was deleted. Return to saved sessions and select again; this preview cannot be shared.',
                              ),
                            if (sharing.message != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(sharing.message!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Builder(
                        builder: (buttonContext) => FilledButton.icon(
                          onPressed:
                              !valid || sharing.busy || sharing.unsupported
                              ? null
                              : () {
                                  WaveHaptics.impact();
                                  final box =
                                      buttonContext.findRenderObject()!
                                          as RenderBox;
                                  ref
                                      .read(comparisonExportProvider.notifier)
                                      .share(
                                        export,
                                        box.localToGlobal(Offset.zero) &
                                            box.size,
                                        isCurrent: () =>
                                            mounted &&
                                            widget.sessions.every(
                                              (snapshot) => ref
                                                  .read(
                                                    comparisonSessionsProvider,
                                                  )
                                                  .sessions
                                                  .any(
                                                    (s) =>
                                                        identical(s, snapshot),
                                                  ),
                                            ),
                                      );
                                },
                          icon: Icon(
                            savesFiles
                                ? Icons.save_alt_rounded
                                : Icons.ios_share_rounded,
                          ),
                          label: Text(
                            sharing.busy
                                ? savesFiles
                                      ? 'Choose export folder…'
                                      : 'Opening share chooser…'
                                : sharing.unsupported
                                ? 'File sharing unavailable'
                                : sharing.message == null
                                ? savesFiles
                                      ? 'Save reviewed files'
                                      : 'Share reviewed files'
                                : savesFiles
                                ? 'Save again'
                                : 'Share again',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          WaveHaptics.selection();
                          Navigator.pop(context);
                        },
                        child: const Text('Return to saved sessions'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WaveReveal(
                child: WavePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.sessions.length} saved sessions · summary + CSV',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        savesFiles
                            ? 'Review both files before saving. Choose a folder; Wave creates a new wave-comparison- subfolder containing both reviewed files. No account or upload by Wave. Aliases are always excluded.'
                            : 'Review both files before sharing. No account or upload by Wave. Sharing writes two local temporary files, overwritten on the next share; system and receiving apps may keep copies. Sharing opens your system chooser; the app you choose controls delivery. Aliases are always excluded.',
                      ),
                      const Text(
                        'Identifiers and room labels are hidden by default. Timing and radio context can still reveal information; this is not an anonymity guarantee.',
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include SSID and BSSID'),
                        subtitle: const Text(
                          'Reveal network name and access point identifier in both files.',
                        ),
                        value: _identifiers,
                        onChanged: sharing.busy
                            ? null
                            : (value) {
                                WaveHaptics.selection();
                                setState(() {
                                  _identifiers = value;
                                  _refreshExport();
                                });
                              },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include room labels'),
                        subtitle: const Text(
                          'User-entered labels may contain names, addresses or network identifiers. Review them below.',
                        ),
                        value: _labels,
                        onChanged: sharing.busy
                            ? null
                            : (value) {
                                WaveHaptics.selection();
                                setState(() {
                                  _labels = value;
                                  _refreshExport();
                                });
                              },
                      ),
                      const Text(
                        'Files: wave-comparison.txt and wave-comparison.csv',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Summary preview'),
                            selected: !_csv,
                            onSelected: (_) {
                              WaveHaptics.selection();
                              setState(() => _csv = false);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('CSV preview'),
                            selected: _csv,
                            onSelected: (_) {
                              WaveHaptics.selection();
                              setState(() => _csv = true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ComparisonExportPreview(
                text: _csv ? export.csv : export.summary,
                csv: _csv,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
