import 'package:material_ui/material_ui.dart';

import '../theme/minute_tokens.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _controller?.dispose();
      _controller = null;
    } else {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.minuteColors;
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: MinuteSpacing.sm),
        itemBuilder: (context, index) {
          final card = Card(
            child: Padding(
              padding: const EdgeInsets.all(MinuteSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(widthFactor: 0.62, height: 16, color: c.surfaceSubtle),
                  const SizedBox(height: MinuteSpacing.sm),
                  _SkeletonBar(widthFactor: 0.38, height: 12, color: c.surfaceSubtle),
                  const SizedBox(height: MinuteSpacing.sm),
                  _SkeletonBar(widthFactor: 0.9, height: 12, color: c.surfaceSubtle),
                ],
              ),
            ),
          );

          final controller = _controller;
          if (controller == null) return card;

          return FadeTransition(
            opacity: Tween<double>(begin: 0.55, end: 1.0).animate(controller),
            child: card,
          );
        },
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(MinuteRadii.sm),
        ),
      ),
    );
  }
}
