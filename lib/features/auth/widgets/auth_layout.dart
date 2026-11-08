import 'package:flutter/widgets.dart';

/// True on phones with limited usable height (under 780 logical pixels).
///
/// The auth screens use compact spacing in this mode so everything fits on
/// one screen without scrolling. It is based on the screen height, not on the
/// space left by the keyboard, so the layout does not jump when the keyboard
/// opens (the page simply scrolls while you type).
bool authIsTight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final pad = MediaQuery.viewPaddingOf(context);

  return size.height - pad.top - pad.bottom < 780;
}
