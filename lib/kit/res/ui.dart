import 'package:flutter/material.dart';

abstract final class UIs {
  static const text11 = TextStyle(fontSize: 11);
  static const text11Bold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const text11Grey = TextStyle(color: Colors.grey, fontSize: 11);
  static const text12 = TextStyle(fontSize: 12);
  static const text12Bold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
  static const text12Grey = TextStyle(color: Colors.grey, fontSize: 12);
  static const text13 = TextStyle(fontSize: 13);
  static const text13Bold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const text13Grey = TextStyle(color: Colors.grey, fontSize: 13);
  static const text15 = TextStyle(fontSize: 15);
  static const text15Bold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  );
  static const text18 = TextStyle(fontSize: 18);
  static const text27 = TextStyle(fontSize: 27);
  static const textGrey = TextStyle(color: Colors.grey);
  static const textRed = TextStyle(color: Colors.red);

  static const placeholder = SizedBox();
  static const height7 = SizedBox(height: 7);
  static const height13 = SizedBox(height: 13);
  static const height77 = SizedBox(height: 77);
  static const width7 = SizedBox(width: 7);
  static const width13 = SizedBox(width: 13);

  static Widget dot({Color? color, double? size}) => Container(
        width: size ?? 7,
        height: size ?? 7,
        decoration: BoxDecoration(
          color: color ?? primaryColor,
          shape: BoxShape.circle,
        ),
      );

  static const centerLoading = Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Center(child: CircularProgressIndicator()),
  );

  static var colorSeed = const Color.fromARGB(255, 72, 15, 15);
  static var primaryColor = colorSeed;
}
