enum ModLoader {
  forge("assets/icons/forge.svg"),
  fabric("assets/icons/fabric.svg"),
  neoforge("assets/icons/neoforge.svg"),
  native("assets/icons/forge.svg");

  final String svgIconAsset;

  const ModLoader(this.svgIconAsset);

  static ModLoader fromString(String str) {
    switch (str.toLowerCase()) {
      case "forge":
        return ModLoader.forge;
      case "fabric":
        return ModLoader.fabric;
      case "neoforge":
      case "neoforged":
        return ModLoader.neoforge;
      case _:
        return ModLoader.native;
    }
  }
}
