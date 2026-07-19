import 'package:flutter/material.dart';

/// Wraps [child] with a subtle scale-down on press (100ms, 0.96 → 1.0).
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressed;
  final Duration duration;
  final HitTestBehavior behavior;
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressed = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressed : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
