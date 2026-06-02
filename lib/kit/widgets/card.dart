import 'package:flutter/material.dart';

class CardX extends StatelessWidget {
  final Widget child;
  final Color? color;
  final BorderRadius? radius;
  final Clip clipBehavior;

  const CardX({
    super.key,
    required this.child,
    this.color,
    this.radius,
    this.clipBehavior = Clip.hardEdge,
  });

  static const borderRadius = BorderRadius.all(Radius.circular(13));

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      clipBehavior: clipBehavior,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius ?? borderRadius,
      ),
      elevation: 0,
      child: child,
    );
  }
}
