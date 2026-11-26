import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'Offline — recordings and local notes remain available.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: MinuteSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: MinuteSpacing.md,
          vertical: MinuteSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: MinuteSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
