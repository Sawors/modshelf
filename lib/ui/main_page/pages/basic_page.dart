import 'package:flutter/material.dart';

import '../../../theme/theme_constants.dart';

class BasicPage extends StatelessWidget {
  final String title;
  final Widget child;

  const BasicPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Card(
            margin: EdgeInsets.zero,
            color: theme.canvasColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rectangleRoundingRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Center(
                child: Text(
                  title,
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: cardMargin / 2,
        ),
        Expanded(
            child: SizedBox(
                width: double.infinity,
                child: Card(
                    margin: EdgeInsets.zero,
                    color: theme.canvasColor,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(rectangleRoundingRadius),
                    ),
                    child: child))),
      ],
    );
  }
}
