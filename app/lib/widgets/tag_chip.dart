import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(MinuteRadii.sm),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Remove tag $label',
              child: InkResponse(
                onTap: onDelete,
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: c.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: 'Tag $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MinuteRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}
