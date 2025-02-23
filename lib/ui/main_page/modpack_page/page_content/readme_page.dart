import 'package:flutter/material.dart';

class ReadmePage extends StatelessWidget {
  const ReadmePage({Key? key}) : super(key: key);

  // Future<String> loadDisplayText() async {
  //   Directory? installDir = widget.data.installDir;
  //   if (installDir == null) {
  //     return "";
  //   }
  //   // TODO : allow selection of what to show first
  //   File readmeFile = File(
  //       "${installDir.path}${Platform.pathSeparator}${DirNames.readmeFile}");
  //   File patchnoteFile = File(
  //       "${installDir.path}${Platform.pathSeparator}${DirNames.versionPatchnoteFile}");
  //   if (await readmeFile.exists()) {
  //     return await readmeFile.readAsString();
  //   }
  //   if (await patchnoteFile.exists()) {
  //     return await patchnoteFile.readAsString();
  //   }
  //   return "";
  // }

  @override
  Widget build(BuildContext context) {
    return Container();
    // FutureBuilder(
    //   future: loadDisplayText(),
    //   builder: (context, snapshot) {
    //     return snapshot.data != null
    //         ? MarkdownWidget(
    //             selectable: true,
    //             data: snapshot.data ?? "",
    //           )
    //         : const Center(
    //             child: SizedBox.square(
    //               dimension: 50,
    //               child: CircularProgressIndicator(),
    //             ),
    //           );
    //   });
  }
}
