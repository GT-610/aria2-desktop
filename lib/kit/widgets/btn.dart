import 'package:flutter/material.dart';

import '../res/ui.dart';

enum BtnType {
  row,
  text,
  icon,
  column,
  elevated,
}

Null _defaultOnTap() => null;

const _kGap = 7.0;
const _kPadding = EdgeInsets.all(7);
const _kPlaceholderIcon = Icon(Icons.help_outline);
const _kBorderRadius = BorderRadius.all(Radius.circular(30));

final class Btn extends StatelessWidget {
  final void Function()? onTap;
  final void Function()? onLongTap;
  final String text;
  final Icon? icon;
  final double? gap;
  final TextStyle? textStyle;
  final BtnType type;
  final EdgeInsetsGeometry? padding;
  final MainAxisAlignment? mainAxisAlignment;
  final MainAxisSize? mainAxisSize;
  final BorderRadius? borderRadius;
  final Object? popVal;

  const Btn.text({
    super.key,
    required this.text,
    this.onTap = _defaultOnTap,
    this.textStyle,
    this.padding,
    this.onLongTap,
  })  : type = BtnType.text,
        gap = null,
        mainAxisAlignment = null,
        mainAxisSize = null,
        borderRadius = null,
        popVal = null,
        icon = null;

  const Btn.icon({
    super.key,
    required this.icon,
    this.text = '',
    this.onTap = _defaultOnTap,
    this.padding = _kPadding,
    this.onLongTap,
  })  : type = BtnType.icon,
        gap = null,
        mainAxisAlignment = null,
        mainAxisSize = null,
        borderRadius = null,
        popVal = null,
        textStyle = null;

  const Btn.column({
    super.key,
    required this.text,
    required this.icon,
    this.onTap = _defaultOnTap,
    this.gap,
    this.textStyle,
    this.padding = _kPadding,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.borderRadius = _kBorderRadius,
    this.onLongTap,
  })  : type = BtnType.column,
        popVal = null;

  const Btn.row({
    super.key,
    required this.text,
    required this.icon,
    this.onTap = _defaultOnTap,
    this.gap,
    this.textStyle,
    this.padding = _kPadding,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.borderRadius = _kBorderRadius,
    this.onLongTap,
  })  : type = BtnType.row,
        popVal = null;

  const Btn.tile({
    super.key,
    required this.text,
    required this.icon,
    this.onTap = _defaultOnTap,
    this.gap = 20,
    this.textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    this.padding = const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.borderRadius = const BorderRadius.all(Radius.circular(13)),
    this.onLongTap,
  })  : type = BtnType.row,
        popVal = null;

  const Btn.elevated({
    super.key,
    required this.text,
    this.icon,
    this.onTap = _defaultOnTap,
    this.gap = 20,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.borderRadius = const BorderRadius.all(Radius.circular(13)),
    this.onLongTap,
  })  : type = BtnType.elevated,
        popVal = null;

  const Btn.ok({
    super.key,
    this.onTap = _defaultOnTap,
    bool red = false,
    this.onLongTap,
    String? text,
  })  : this.text = text ?? 'OK',
        icon = null,
        type = BtnType.text,
        gap = null,
        padding = null,
        mainAxisAlignment = null,
        mainAxisSize = null,
        borderRadius = null,
        popVal = true,
        textStyle = red ? UIs.textRed : null;

  const Btn.cancel({
    super.key,
    this.onTap = _defaultOnTap,
    this.onLongTap,
    String? text,
  })  : this.text = text ?? 'Cancel',
        icon = null,
        type = BtnType.text,
        gap = null,
        padding = null,
        mainAxisAlignment = null,
        mainAxisSize = null,
        borderRadius = null,
        popVal = false,
        textStyle = null;

  @override
  Widget build(BuildContext context) => switch (type) {
        BtnType.text => _text(context),
        BtnType.icon => _icon(context),
        BtnType.column => _column(context),
        BtnType.row => _row(context),
        BtnType.elevated => _elevated(context),
      };

  VoidCallback? _resolveOnTap(BuildContext c) {
    if (onTap == _defaultOnTap) {
      if (popVal != null) return () => Navigator.of(c).pop(popVal);
      return () => Navigator.of(c).pop();
    }
    return onTap;
  }

  Widget _text(BuildContext context) {
    return TextButton(
      onPressed: _resolveOnTap(context),
      onLongPress: onLongTap,
      style: padding != null
          ? ButtonStyle(padding: WidgetStateProperty.all(padding))
          : null,
      child: Text(text, style: textStyle),
    );
  }

  Widget _icon(BuildContext context) {
    Widget child = Tooltip(
      message: text,
      child: icon ?? _kPlaceholderIcon,
    );
    if (padding != null) child = Padding(padding: padding!, child: child);
    return InkWell(
      borderRadius: borderRadius ?? _kBorderRadius,
      onTap: _resolveOnTap(context),
      onLongPress: onLongTap,
      child: child,
    );
  }

  Widget _column(BuildContext context) {
    Widget child = Column(
      children: [
        icon ?? _kPlaceholderIcon,
        SizedBox(height: gap ?? _kGap),
        Text(text, style: textStyle),
      ],
    );
    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }
    return InkWell(
      borderRadius: borderRadius ?? _kBorderRadius,
      onTap: _resolveOnTap(context),
      onLongPress: onLongTap,
      child: child,
    );
  }

  Widget _row(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final icon_ = icon ?? _kPlaceholderIcon;
    final gap_ = SizedBox(width: gap ?? _kGap);
    final text_ = Text(text, style: textStyle);
    final children = isRTL ? [text_, gap_, icon_] : [icon_, gap_, text_];

    Widget child = Row(
      mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
      mainAxisSize: mainAxisSize ?? MainAxisSize.max,
      children: children,
    );
    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }
    return InkWell(
      borderRadius: borderRadius ?? _kBorderRadius,
      onTap: _resolveOnTap(context),
      onLongPress: onLongTap,
      child: child,
    );
  }

  Widget _elevated(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final btnStyle = ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: borderRadius ?? _kBorderRadius),
      ),
    );
    final text_ = Text(text, style: textStyle);

    if (icon != null) {
      final gap_ = SizedBox(width: gap ?? _kGap);
      final children = isRTL ? [text_, gap_, icon!] : [icon!, gap_, text_];

      return ElevatedButton(
        onPressed: _resolveOnTap(context),
        onLongPress: onLongTap,
        style: btnStyle,
        child: Row(
          mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
          mainAxisSize: mainAxisSize ?? MainAxisSize.max,
          children: children,
        ),
      );
    }

    return ElevatedButton(
      onPressed: _resolveOnTap(context),
      onLongPress: onLongTap,
      style: btnStyle,
      child: text_,
    );
  }
}
