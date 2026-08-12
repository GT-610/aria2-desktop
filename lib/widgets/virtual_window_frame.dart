import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' as wm;

class AppVirtualWindowFrame extends StatelessWidget {
  const AppVirtualWindowFrame({
    super.key,
    required this.child,
    this.title,
    this.showCaption = true,
  });

  final Widget child;
  final String? title;
  final bool showCaption;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final content = showCaption && _isDesktop
        ? Column(
            children: [
              _WindowCaption(title: title),
              Expanded(child: child),
            ],
          )
        : child;
    return wm.VirtualWindowFrame(child: content);
  }
}

class _WindowCaption extends StatelessWidget {
  const _WindowCaption({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      height: wm.kWindowCaptionHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Material(
              color: Colors.transparent,
              child: Text(
                title!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (Platform.isWindows || Platform.isLinux)
            wm.WindowCaption(
              backgroundColor: Colors.transparent,
              brightness: theme.brightness,
            ),
        ],
      ),
    );
  }
}
