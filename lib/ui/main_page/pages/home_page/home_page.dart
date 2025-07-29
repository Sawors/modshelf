import 'package:flutter/material.dart';

import '../../../../theme/theme_constants.dart';
import '../../sidebar/sidebar.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final flutterTheme = Theme.of(context);
    return Center(
      child: Card(
        elevation: 4,
        color: flutterTheme.canvasColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rectangleRoundingRadius)),
        child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rectangleRoundingRadius),
              border: Border.all(
                  color: flutterTheme.colorScheme.primary, width: 3)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add a Pack",
                  style: flutterTheme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Card(
                    shape: const CircleBorder(),
                    color: flutterTheme.colorScheme.surfaceContainer,
                    child: SizedBox.square(
                        dimension: 50,
                        child:
                            getAddButton(context, const Duration(seconds: 1))),
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
