import 'package:flutter/material.dart';

import '../core/ext/widget.dart';

final class SizedLoading extends StatelessWidget {
  final double size;
  final double padding;
  final Animation<Color>? valueColor;
  final Widget Function(BuildContext context, Animation<Color>? valueColor)
  builder;

  const SizedLoading(
    this.size, {
    this.padding = 7,
    this.valueColor,
    this.builder = linearBuilder,
    super.key,
  });

  static Widget linearBuilder(
    BuildContext context,
    Animation<Color>? valueColor,
  ) {
    return LinearProgressIndicator(
      valueColor:
          valueColor ??
          AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size - 2 * padding,
      height: size - 2 * padding,
      child: Center(child: builder(context, valueColor)).paddingAll(padding),
    ).paddingAll(3);
  }

  static const small = SizedLoading(25);
  static const medium = SizedLoading(45);
  static const large = SizedLoading(65);
}
