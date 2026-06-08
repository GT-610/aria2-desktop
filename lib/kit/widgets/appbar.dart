import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  static final sysStatusBarHeight = isDesktop ? kWindowCaptionHeight : 0.0;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.centerTitle = true,
    this.leading,
    this.backgroundColor,
    this.bottom,
    this.scrolledUnderElevation = 0,
    this.surfaceTintColor = Colors.transparent,
  });

  final Widget? title;
  final List<Widget>? actions;
  final bool? centerTitle;
  final Widget? leading;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final double scrolledUnderElevation;
  final Color surfaceTintColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      centerTitle: centerTitle,
      leading: leading,
      backgroundColor: backgroundColor,
      toolbarHeight: appBarHeight,
      bottom: bottom,
      scrolledUnderElevation: scrolledUnderElevation,
      surfaceTintColor: surfaceTintColor,
    );
  }

  @override
  Size get preferredSize {
    return calcPreferredSize(bottomWidgetH: bottom?.preferredSize.height);
  }

  static const double appBarHeight = kToolbarHeight - 10;

  static Size calcPreferredSize({double? bottomWidgetH}) {
    bottomWidgetH ??= 0;
    return Size.fromHeight(appBarHeight + bottomWidgetH);
  }
}
