import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modshelf/ui/main_page/pages/download_page/download_manager_page.dart';
import 'package:modshelf/ui/main_page/pages/home_page/home_page.dart';
import 'package:modshelf/ui/main_page/pages/settings_page/settings_page.dart';
import 'package:modshelf/ui/main_page/sidebar/sidebar.dart';

import '../../main.dart';
import '../../theme/theme_constants.dart';
import '../../tools/cache.dart';
import '../../tools/core/core.dart';
import 'pages/modpack_page/modpack_page.dart';

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

class MainPage extends StatelessWidget {
  static final NamespacedKey indexCacheKey =
      NamespacedKey.fromString("state:mainpage.index");
  static const String pageStateIdentifier = "page:modpacks-list";
  static const NamespacedKey manifestsKey =
      NamespacedKey(pageStateIdentifier, "manifests");
  static const NamespacedKey indexKey =
      NamespacedKey(pageStateIdentifier, "index");
  static const NamespacedKey mainPageKey = NamespacedKey("home", "home");

  const MainPage({super.key});

  static void goToPage(NamespacedKey page) {
    final oldPage = getCurrentPage().toString();
    CacheManager.instance.setCachedEntry(
        MainPage.indexCacheKey, CacheEntry.immortal(page.toString()));
    PageState.getInstance(page.toString()).setStateValue("selected", true);
    PageState.getInstance(oldPage).setStateValue("selected", false);
    PageState.setValue(MainPage.indexKey, page.toString());
  }

  static NamespacedKey getCurrentPage() {
    return NamespacedKey.fromStringOrNull(
            CacheManager.instance.getCachedValue(indexCacheKey) ?? "") ??
        MainPage.mainPageKey;
  }

  Widget _getDisplayedPage(BuildContext context, String key,
      {List<ModpackData>? modpacks}) {
    final String keyDomain = key.split(":").firstOrNull ?? "";
    final String keyValue = key.split(":").lastOrNull ?? "";
    NamespacedKey nmp = NamespacedKey(keyDomain, keyValue);
    switch (nmp.namespace) {
      case "index":
        final index = int.tryParse(keyValue) ?? -1;
        final List<ModpackData> mdpk =
            modpacks ?? PageState.getValue(MainPage.manifestsKey) ?? [];
        if (mdpk.isEmpty || index < 0 || index >= mdpk.length) {
          return _getDisplayedPage(context, "home", modpacks: mdpk);
        }
        return ModpackPage(modpackData: mdpk[index]);
      case "downloads":
        return const DownloadManagerPage();
      case "settings":
        return const SettingsPage();
      case "popup":
        switch (keyValue) {
          case "force-restart":
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Restart now !"),
                  TextButton(
                      onPressed: () {
                        SystemChannels.platform
                            .invokeMethod('SystemNavigator.pop');
                      },
                      child: const Text("EXIT"))
                ],
              ),
            );
          case _:
            return const Text("Hello :)");
        }
      case _:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: ListenableBuilder(
          listenable: PageState.getInstance(MainPage.pageStateIdentifier),
          builder: (BuildContext context, Widget? child) {
            final modpacks = PageState.getValue(MainPage.manifestsKey) ?? [];
            final subpage = getCurrentPage();
            final Widget pageDisplayed;
            if (subpage.namespace == "popup") {
              return _getDisplayedPage(context, subpage.toString(),
                  modpacks: modpacks);
            } else {
              pageDisplayed = _getDisplayedPage(context, subpage.toString(),
                  modpacks: modpacks);
            }
            return Row(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Sidebar(
                        modpackList: modpacks,
                        selectedSubpage: subpage,
                      ),
                    ),
                  ],
                ),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                            padding:
                                const EdgeInsets.only(left: cardMargin * 2),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1920),
                              child: pageDisplayed,
                            ))))
              ],
            );
          }),
    );
  }
}
