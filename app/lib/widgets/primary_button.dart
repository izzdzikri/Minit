import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    final style = isDestructive
        ? FilledButton.styleFrom(
            backgroundColor: c.danger,
            foregroundColor: c.accentForeground,
            minimumSize: const Size(48, 48),
          )
        : FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.accentForeground,
            minimumSize: const Size(48, 48),
          );

    final button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FilledButton(
        style: style,
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.accentForeground,
                ),
              ),
              const SizedBox(width: MinuteSpacing.sm),
            ] else if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: MinuteSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      child: button,
    );
  }
}
