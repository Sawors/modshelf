import 'package:flutter/material.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/ui/main_page/main_page.dart';

import '../../../main.dart';
import '../../../theme/theme_constants.dart';

class PageNavigationButton extends StatelessWidget {
  final Widget child;
  final NamespacedKey trackedPage;
  final Color? colorSelected;
  final Color? colorUnselected;
  final double? minWidth;
  final double? minHeight;
  final double? elevation;
  final ShapeBorder Function(BuildContext context, bool selected)? shape;

  const PageNavigationButton(
      {super.key,
      required this.trackedPage,
      required this.child,
      this.minWidth,
      this.minHeight,
      this.shape,
      this.elevation,
      this.colorSelected,
      this.colorUnselected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
        listenable: PageState.getInstance(trackedPage.toString()),
        builder: (context, child) {
          final selected = MainPage.getCurrentPage() == trackedPage;
          return MaterialButton(
            onPressed: () {
              final value = selected ? MainPage.mainPageKey : trackedPage;
              MainPage.goToPage(value);
            },
            splashColor: Colors.transparent,
            animationDuration: const Duration(milliseconds: 300),
            color: selected
                ? theme.colorScheme.surfaceContainerLow
                : theme.canvasColor,
            shape: shape != null
                ? shape!(context, selected)
                : RoundedRectangleBorder(
                    side: selected
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide(
                            width: 2,
                            color:
                                Theme.of(context).colorScheme.surfaceContainer),
                    borderRadius:
                        BorderRadius.circular(rectangleRoundingRadius - 6)),
            minWidth: minWidth ?? double.infinity,
            height: minHeight,
            elevation: elevation ?? 0,
            child: this.child,
          );
        });
  }
}
