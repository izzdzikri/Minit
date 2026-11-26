import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: MinuteSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.textSecondary,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
