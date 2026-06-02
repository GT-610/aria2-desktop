import 'package:flutter/material.dart';

import '../core/ext/widget.dart';
import 'card.dart';

class Input extends StatefulWidget {
  final TextEditingController? controller;
  final int maxLines;
  final int? minLines;
  final String? hint;
  final String? label;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final bool obscureText;
  final Widget? suffix;
  final IconData? icon;
  final TextInputType? type;
  final TextInputAction? action;
  final FocusNode? node;
  final bool autoCorrect;
  final bool? suggestion;
  final String? errorText;
  final bool autoFocus;
  final void Function(bool)? onViewPwdTap;
  final bool noWrap;
  final InputCounterWidgetBuilder? counterBuilder;
  final void Function()? onTap;
  final void Function(PointerDownEvent)? onTapOutside;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final int? maxLength;
  final bool? enabled;

  const Input({
    super.key,
    this.controller,
    this.maxLines = 1,
    this.minLines,
    this.hint,
    this.label,
    this.onSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.icon,
    this.type,
    this.action,
    this.node,
    this.autoCorrect = false,
    this.suggestion,
    this.errorText,
    this.autoFocus = false,
    this.onViewPwdTap,
    this.noWrap = false,
    this.suffix,
    this.counterBuilder,
    this.onTap,
    this.onTapOutside,
    this.contextMenuBuilder,
    this.maxLength,
    this.enabled,
  }) : assert(
         !(obscureText && suffix != null),
         'suffix != null && obscureText',
       );

  @override
  State<StatefulWidget> createState() => _InputState();
}

class _InputState extends State<Input> {
  late bool _obscureText = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon != null
        ? Icon(widget.icon!).paddingOnly(left: 5)
        : null;
    final child = _buildField(icon);

    if (widget.noWrap) return child;

    return CardX(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        child: child,
      ),
    );
  }

  Widget _buildField(Widget? icon) {
    return TextField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.label,
        errorText: widget.errorText,
        border: InputBorder.none,
        icon: icon,
        suffixIcon: _buildSuffix(),
      ),
      keyboardType: widget.type,
      textInputAction: widget.action,
      focusNode: widget.node,
      autocorrect: widget.autoCorrect,
      enableSuggestions: widget.suggestion ?? true,
      autofocus: widget.autoFocus,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      buildCounter: widget.counterBuilder,
      onTap: widget.onTap,
      onTapOutside: widget.onTapOutside,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      contextMenuBuilder:
          widget.contextMenuBuilder ??
          (context, state) => AdaptiveTextSelectionToolbar.editableText(
            editableTextState: state,
          ),
    );
  }

  Widget? _buildSuffix() {
    if (widget.suffix != null) return widget.suffix!;
    if (!widget.obscureText) return null;

    return IconButton(
      icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
      onPressed: () {
        setState(() {
          _obscureText = !_obscureText;
        });
        widget.onViewPwdTap?.call(_obscureText);
      },
    );
  }
}
