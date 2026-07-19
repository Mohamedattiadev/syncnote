import 'package:flutter/material.dart';

/// Fade + slight scale (0.97 → 1.0) page transition. Use instead of
/// [MaterialPageRoute] for the polished Fabric-style motion.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  FadeScalePageRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (ctx, a, s) => builder(ctx),
          transitionsBuilder: (ctx, anim, sec, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}
