import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

import '../tools/utils.dart';

Color reverseColorBrightness(Color color) {
  HSVColor hsv = HSVColor.fromColor(color);
  double value = hsv.value;
  double midDelta = value - 0.5;
  double reverseValue = 0.5 - midDelta;
  return HSVColor.fromAHSV(hsv.alpha, hsv.hue, hsv.saturation, reverseValue)
      .toColor();
}

Color colorForThemeBrightness(ThemeData theme, Color color,
    {double hsvValueDelta = 0.25}) {
  bool isLight = theme.brightness == Brightness.light;
  HSVColor hsv = HSVColor.fromColor(color);
  return HSVColor.fromAHSV(
          hsv.alpha, hsv.hue, hsv.saturation, isLight ? 1 - hsvValueDelta : 1)
      .toColor();
}

final class StyledMenuItem<T> extends ContextMenuItem<T> {
  final Widget label;
  final IconData? icon;
  final Widget? iconWidget;
  final BoxConstraints? constraints;

  const StyledMenuItem({
    required this.label,
    this.icon,
    this.iconWidget,
    super.value,
    super.onSelected,
    this.constraints,
  });

  const StyledMenuItem.submenu({
    required this.label,
    required List<ContextMenuEntry> items,
    this.icon,
    this.iconWidget,
    super.onSelected,
    this.constraints,
  }) : super.submenu(items: items);

  @override
  Widget builder(BuildContext context, ContextMenuState menuState,
      [FocusNode? focusNode]) {
    bool isFocused = menuState.focusedEntry == this;

    final theme = Theme.of(context);

    final background = theme.colorScheme.surface;
    final normalTextColor = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.7),
      background,
    );
    final focusedTextColor = theme.colorScheme.onSurface;
    final foregroundColor = isFocused ? focusedTextColor : normalTextColor;
    final textStyle = TextStyle(color: foregroundColor, height: 1.0);

    // ~~~~~~~~~~ //

    return ConstrainedBox(
      constraints: constraints ?? const BoxConstraints.expand(height: 32.0),
      child: Material(
        color: isFocused ? theme.focusColor.withAlpha(20) : background,
        borderRadius: BorderRadius.circular(4.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => handleItemSelection(context),
          canRequestFocus: false,
          child: DefaultTextStyle(
            style: textStyle,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 32.0,
                  child: iconWidget ??
                      Icon(
                        icon,
                        size: 16,
                        color: foregroundColor,
                      ),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: label,
                ),
                const SizedBox(width: 8.0),
                SizedBox.square(
                  dimension: 32.0,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Icon(
                      isSubmenuItem ? Icons.arrow_right : null,
                      size: 16.0,
                      color: foregroundColor,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Image? buildImageFromUri(Uri uri) {
  if (uri.isScheme("http")) {
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
    );
  } else if (uri.isScheme("file")) {
    File? f = getRandomFile(uri);
    if (f == null) {
      return null;
    }
    return Image.file(
      f,
      fit: BoxFit.cover,
    );
  }
  return null;
}
