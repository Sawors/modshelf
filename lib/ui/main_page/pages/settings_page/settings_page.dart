import 'package:flutter/material.dart';
import 'package:modshelf/tools/cache.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/ui/main_page/pages/basic_page.dart';

import '../../../../theme/theme_constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  static const NamespacedKey settingsPageKey = NamespacedKey("settings", "1");

  @override
  Widget build(BuildContext context) {
    return BasicPage(
        title: "Settings",
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: MaterialButton(
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: 2,
                            color:
                                Theme.of(context).colorScheme.surfaceContainer),
                        borderRadius:
                            BorderRadius.circular(rectangleRoundingRadius - 6)),
                    onPressed: () {
                      CacheManager.managedCacheDirectory
                          .then((d) => d.delete(recursive: true))
                          .then((r) {
                        CacheManager.instance.cacheState.clear();
                        CacheManager.instance.cacheNamespaceToSave.clear();
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "Clear Cache\n( may break everything )",
                        textAlign: TextAlign.center,
                      ),
                    )),
              )
            ],
          ),
        ));
  }
}
