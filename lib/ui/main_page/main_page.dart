import 'package:flutter/material.dart';
import 'package:modshelf/ui/main_page/sidebar.dart';

import '../../main.dart';
import '../../tools/core/core.dart';
import 'modpack_page/modpack_page.dart';

// class ModpackPageStatusContainer extends InheritedWidget {
//   final List<ModpackData> modpackList;
//   final int selectedIndex;
//   final void Function(List<ModpackData>) onListUpdate;
//   final void Function(int) onIndexUpdate;
//
//   const ModpackPageStatusContainer(
//       {super.key,
//       required this.modpackList,
//       required this.selectedIndex,
//       required this.onListUpdate,
//       required this.onIndexUpdate,
//       required super.child});
//
//   static ModpackPageStatusContainer? maybeOf(BuildContext context) {
//     return context
//         .dependOnInheritedWidgetOfExactType<ModpackPageStatusContainer>();
//   }
//
//   static ModpackPageStatusContainer of(BuildContext context) {
//     final ModpackPageStatusContainer? result = maybeOf(context);
//     assert(result != null, 'No ModpackList found in context');
//     return result!;
//   }
//
//   ModpackData pop(int index) {
//     ModpackData data = modpackList[index];
//     onListUpdate(modpackList..removeAt(index));
//     return data;
//   }
//
//   @override
//   bool updateShouldNotify(covariant ModpackPageStatusContainer oldWidget) {
//     if (oldWidget.modpackList != modpackList) {
//       print("rebuild");
//     }
//     return oldWidget.modpackList != modpackList;
//   }
// }

class ModpackListPage extends StatelessWidget {
  static final NamespacedKey indexCacheKey =
      NamespacedKey.fromString("general:mainpage.index");
  static const String pageStateIdentifier = "modpacks-list";
  static final NamespacedKey manifestsKey =
      NamespacedKey(pageStateIdentifier, "manifests");
  static final NamespacedKey indexKey =
      NamespacedKey(pageStateIdentifier, "index");

  const ModpackListPage({super.key});

  @override
  Widget build(BuildContext context) {
    int index = int.tryParse(
            CacheManager.getCachedValue(ModpackListPage.indexCacheKey) ??
                "-1") ??
        -1;
    List<ModpackData> modpacks = [];

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: ListenableBuilder(
          listenable:
              PageState.getInstance(ModpackListPage.pageStateIdentifier),
          // modpackList: modpacks,
          // selectedIndex: index,
          // onIndexUpdate: (newIndex) {
          //   setState(() {
          //     index = newIndex;
          //     CacheManager.setCachedValue(indexCacheKey, index.toString());
          //   });
          // },
          // onListUpdate: (newList) {
          //   setState(() {
          //     modpacks = newList;
          //   });
          // },
          builder: (BuildContext context, Widget? child) {
            modpacks = PageState.getValue(ModpackListPage.manifestsKey) ?? [];
            index = int.tryParse(CacheManager.getCachedValue(
                        ModpackListPage.indexCacheKey) ??
                    "-1") ??
                -1;

            return Row(
              children: [
                Sidebar(modpackList: modpacks, selectedIndex: index),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: ModpackPage(
                            modpackData: modpacks.isNotEmpty &&
                                    index >= 0 &&
                                    index < modpacks.length
                                ? modpacks[index]
                                : null)))
              ],
            );
          }),
    );
  }
}
