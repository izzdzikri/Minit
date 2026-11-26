import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/app_providers.dart';
import '../services/app_settings.dart';

/// Checks whether upload consent has been accepted for the configured server
/// URL; prompts once if not and persists consent before returning `true`.
Future<bool> ensureUploadConsent(BuildContext context, WidgetRef ref) async {
  final settings =
      ref.read(settingsControllerProvider).value ?? await AppSettingsStorage.load();
  final url = AppSettings.normalizeServerUrl(settings.serverUrl);
  if (settings.hasConsentedFor(url)) return true;
  if (!context.mounted) return false;
  final accepted = await showUploadConsentDialog(
    context,
    serverUrl: url.isEmpty ? 'Configured server' : url,
  );
  if (!accepted || !context.mounted) return false;
  await ref.read(settingsControllerProvider.notifier).acceptUploadConsent(url);
  return true;
}

/// One-time consent dialog shown before uploading any meeting audio to a server URL.
Future<bool> showUploadConsentDialog(
  BuildContext context, {
  required String serverUrl,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Send audio for transcription?'),
      content: Text(
        'Audio for your recordings will be uploaded to your configured '
        'transcription server:\n\n$serverUrl\n\n'
        'Only upload recordings you are authorized to transcribe.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Allow upload'),
        ),
      ],
    ),
  );
  return result ?? false;
}
