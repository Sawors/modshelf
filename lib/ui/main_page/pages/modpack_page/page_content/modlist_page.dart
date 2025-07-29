import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/core/core.dart';

class ModlistPage extends StatelessWidget {
  final ModpackData modpackData;

  const ModlistPage({super.key, required this.modpackData});

  @override
  Widget build(BuildContext context) {
    final Directory? rootDir = modpackData.installDir;
    if (rootDir == null) {
      return const Center(
        child: Text("No install dir"),
      );
    }
    return Align(
      alignment: AlignmentGeometry.topLeft,
      child: SizedBox(
        width: 500,
        child: FutureBuilder(
            future:
                Directory("${rootDir.path}/${DirNames.mods}").list().toList(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? [];
              return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final file = data[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                rectangleRoundingRadius / 2),
                            border: Border.all(
                                width: 2,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Text(
                            file.uri.pathSegments.last.replaceAll(".jar", ""),
                            style: GoogleFonts.robotoMono(
                                textStyle:
                                    Theme.of(context).textTheme.bodyMedium),
                          ),
                        ),
                      ),
                    );
                  });
            }),
      ),
    );
  }
}
