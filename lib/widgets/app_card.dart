import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.borderRadius,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final Color? color;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: clipBehavior,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(13),
      ),
      elevation: 0,
      child: child,
    );
  }
}
