import 'package:flutter/material.dart';

import '../res/ui.dart';

final class CenterGreyTitle extends StatelessWidget {
  final String text;

  const CenterGreyTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 23, bottom: 17),
      child: Center(
        child: Text(text, style: UIs.textGrey),
      ),
    );
  }
}
