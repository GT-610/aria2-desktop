import 'package:flutter/material.dart';

class SizedLoading extends StatelessWidget {
  const SizedLoading(this.size, {super.key, this.padding = 7});

  final double size;
  final double padding;

  static const small = SizedLoading(25);
  static const medium = SizedLoading(45);
  static const large = SizedLoading(65);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: CircularProgressIndicator(strokeWidth: size < 30 ? 2 : 3),
      ),
    );
  }
}
