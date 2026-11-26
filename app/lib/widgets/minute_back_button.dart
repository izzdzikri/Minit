import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Leading app-bar back arrow for non-root screens.
/// Pops the current route when possible, otherwise returns to `/library`.
class MinuteBackButton extends StatelessWidget {
  const MinuteBackButton({
    super.key,
    this.onBeforeNavigate,
    this.onPressedOverride,
  });

  final VoidCallback? onBeforeNavigate;
  final VoidCallback? onPressedOverride;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: IconButton(
        tooltip: 'Back',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onPressedOverride ??
            () {
              onBeforeNavigate?.call();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}
