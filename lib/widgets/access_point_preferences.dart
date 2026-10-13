import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_point.dart';
import '../models/ap_preference.dart';
import '../repositories/ap_preferences_repository.dart';
import '../viewmodels/ap_preferences_view_model.dart';
import 'wave_haptics.dart';
import 'wave_motion.dart';

/// Preference feedback stays separate from scan status.
class ApPreferencesStatus extends ConsumerWidget {
  const ApPreferencesStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (loading, saving, error) = ref.watch(
      apPreferencesProvider.select((s) => (s.loading, s.saving, s.error)),
    );
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Local preferences: $error'),
            TextButton.icon(
              onPressed: () {
                WaveHaptics.selection();
                ref.read(apPreferencesProvider.notifier).retry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry preferences'),
            ),
          ],
        ),
      );
    }
    if (!loading && !saving) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        loading ? 'Loading local preferences…' : 'Saving local preferences…',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class AccessPointPreferences extends ConsumerWidget {
  const AccessPointPreferences({super.key, this.ap, this.saved})
    : assert(ap != null || saved != null);
  final AccessPoint? ap;
  final ApPreference? saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = preferenceKey(ap?.bssid ?? saved!.bssid);
    final entry = ref.watch(
      apPreferencesProvider.select((state) => state.entries[key]),
    );
    final favorite = entry?.favorite ?? false;
    final alias = entry?.alias;
    final notifier = ref.read(apPreferencesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                WaveHaptics.selection();
                if (ap != null) {
                  notifier.setFavorite(ap!, !favorite);
                } else {
                  notifier.updateSaved(entry ?? saved!, favorite: !favorite);
                }
              },
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              label: Text(favorite ? 'Remove favorite' : 'Add favorite'),
            ),
            OutlinedButton.icon(
              onPressed: () => _editAlias(context, ref, entry),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                alias == null ? 'Add local alias' : 'Edit local alias',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Saved on this device for this BSSID. Router names stay unchanged.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const ApPreferencesStatus(),
      ],
    );
  }

  Future<void> _editAlias(
    BuildContext context,
    WidgetRef ref,
    ApPreference? entry,
  ) async {
    WaveHaptics.selection();
    final result = await showDialog<_AliasEdit>(
      context: context,
      animationStyle: WaveMotion.sheetStyle(context),
      builder: (context) => _AliasDialog(alias: entry?.alias),
    );
    if (result == null || !context.mounted) return;
    WaveHaptics.selection();
    final notifier = ref.read(apPreferencesProvider.notifier);
    if (ap != null) {
      notifier.setAlias(ap!, result.alias);
    } else {
      notifier.updateSaved(
        entry ?? saved!,
        alias: result.alias,
        clearAlias: result.alias == null,
      );
    }
  }
}

class _AliasEdit {
  const _AliasEdit(this.alias);
  final String? alias;
}

class _AliasDialog extends StatefulWidget {
  const _AliasDialog({this.alias});
  final String? alias;
  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  late final TextEditingController _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.alias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.length > maxAliasLength) {
      setState(() => _error = 'Alias too long. Try a shorter name.');
      return;
    }
    Navigator.of(context).pop(_AliasEdit(text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Local alias'),
    scrollable: true,
    content: SingleChildScrollView(
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxAliasLength,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          errorText: _error,
          labelText: 'Name on this device',
          hintText: 'e.g. Living room router',
          helperText: 'Original SSID remains visible.',
        ),
      ),
    ),
    actions: [
      if (widget.alias != null)
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _AliasEdit(null)),
          child: const Text('Remove alias'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
