import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

enum StatusChipTone { neutral, accent, warning, danger, success }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
    this.semanticLabel,
  });

  factory StatusChip.fromMeetingStatus(String status) {
    final lower = status.toLowerCase();
    final tone = switch (lower) {
      'ready' => StatusChipTone.success,
      'recording' => StatusChipTone.accent,
      'uploading' || 'transcribing' || 'summarizing' => StatusChipTone.warning,
      'failed' || 'error' => StatusChipTone.danger,
      _ => StatusChipTone.neutral,
    };
    return StatusChip(label: status, tone: tone, semanticLabel: 'Status: $status');
  }

  final String label;
  final StatusChipTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final (Color bg, Color fg, Color border) = switch (tone) {
      StatusChipTone.accent => (c.accentSubtle, c.accentText, c.accentSubtle),
      StatusChipTone.warning => (c.warningSubtle, c.warning, c.warningSubtle),
      StatusChipTone.danger => (c.dangerSubtle, c.danger, c.dangerSubtle),
      StatusChipTone.success => (c.successSubtle, c.success, c.successSubtle),
      StatusChipTone.neutral => (c.surfaceSubtle, c.textSecondary, c.border),
    };

    return Semantics(
      label: semanticLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MinuteRadii.pill),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
