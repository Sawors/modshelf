import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

Stream<(int, int, File, bool)> downloadFileTemp(Uri source,
    {int periodMs = 100}) async* {
  final tempDir = Directory.systemTemp;
  final targetFile = File(
      "${tempDir.path}${Platform.pathSeparator}modshelf_${generateRandomStringAlNum(16)}.zip");
  var status = (0, 0, targetFile, false);
  Dio()
      .downloadUri(source, targetFile.path,
          onReceiveProgress: (currentBytes, totalBytes) =>
              status = (currentBytes, totalBytes, targetFile, false))
      .whenComplete(() => status = (status.$1, status.$2, status.$3, true));
  yield* Stream.periodic(Duration(milliseconds: periodMs), (_) {
    return status;
  });

  //.then((_) => targetFile);
}

String generateRandomString(int len, {List<int>? dict}) {
  var r = Random();
  dict ??= [for (var i = 89; i <= 122; i += 1) i];
  List<int> charcodes = List.generate(len, (index) {
    var res = r.nextInt(dict!.length - 1) + 1;
    return dict[res];
  });
  return String.fromCharCodes(charcodes);
}

String generateRandomStringAlpha(int len, {bool allowCapitals = true}) {
  return generateRandomString(len,
      dict: (allowCapitals
              ? [for (var i = 65; i <= 90; i += 1) i]
              : [] as List<int>) +
          [for (var i = 97; i <= 122; i += 1) i]);
}

String generateRandomStringAlNum(int len, {bool allowCapitals = true}) {
  return generateRandomString(len,
      dict: [for (var i = 48; i <= 57; i += 1) i] +
          (allowCapitals
              ? [for (var i = 65; i <= 90; i += 1) i]
              : [] as List<int>) +
          [for (var i = 97; i <= 122; i += 1) i]);
}

File? getRandomFile(Uri source, {String mimeFilter = ""}) {
  String path = source.path;
  if (FileSystemEntity.isDirectorySync(path)) {
    Directory dir = Directory(path);
    List<FileSystemEntity> possibleBackgrounds = dir
        .listSync()
        .where((f) =>
            FileSystemEntity.isFileSync(f.path) &&
            (lookupMimeType(f.path)?.startsWith(mimeFilter) ?? false))
        .toList(growable: false);
    int i = Random().nextInt(possibleBackgrounds.length - 1);
    return possibleBackgrounds[i] as File;
  } else if (FileSystemEntity.isFileSync(path)) {
    return File(path);
  }

  return null;
}

String bytesToDisplay(num bytes,
    {int outputDecimals = 1,
    int segmentSize = 1024,
    List<String>? dictionary,
    String? dataTypeLetter,
    bool displayUnit = true}) {
  List<String> defaultSuffixes = ["", "K", "M", "G", "T", "P", "E", "Z", "Y"];
  if (dictionary == null) {
    if (dataTypeLetter == null) {
      if (segmentSize == 1024) {
        dataTypeLetter = "iB";
      } else if (segmentSize == 1000) {
        dataTypeLetter = "b";
      }
    }
    dictionary =
        defaultSuffixes.map((e) => e + (dataTypeLetter ?? "?")).toList();
  }
  int orderOfMagnitude = ((log(max(bytes + 1, 1)) / ln10) / 3).floor();
  int orderClamped = max(min(orderOfMagnitude, dictionary.length - 1), 0);
  double divider = pow(segmentSize, orderClamped).toDouble();
  double reduced = bytes / (divider);
  //print("$bytes -> $orderOfMagnitude/$orderClamped -> $divider");
  String numberDisplay = reduced.toStringAsFixed(outputDecimals);
  String unitDisplay = dictionary[orderClamped];
  return numberDisplay + (displayUnit ? " $unitDisplay" : "");
}

String title(String input,
    {String splitPattern = " ", String? replacePattern}) {
  List<String> split = input.split(splitPattern);
  return split.map((v) {
    if (v.isEmpty) {
      return v;
    }
    final v1 = v.substring(0, 1);
    return "${v1.toUpperCase()}${v.substring(1)}";
  }).join(replacePattern ?? splitPattern);
}

String asPath(Iterable<String> pathSegments) {
  return pathSegments.join(Platform.pathSeparator);
}

String toDurationDisplay(Duration duration,
    {bool minimize = false,
    bool includeDays = true,
    bool showUnit = false,
    bool useZeroPadding = true,
    String separator = ":",
    String padding = "0"}) {
  String result = "";

  List<int> durationSplit = [
    duration.inDays,
    includeDays ? duration.inHours : duration.inHours.remainder(24),
    duration.inMinutes.remainder(60),
    duration.inSeconds.remainder(60)
  ];

  final List<String> units = ["d", "h", "m", "s"];

  for (int i = 0; i < durationSplit.length; i++) {
    int value = durationSplit[i];
    if ((i > 0 || includeDays) &&
        (value > 0 || !minimize || i == durationSplit.length - 1)) {
      String str = value.toString();
      if (useZeroPadding) {
        str = str.padLeft(2, padding);
      }
      if (showUnit) {
        str += units[i];
      }
      result += "$separator$str";
    }
  }

  return result.isNotEmpty ? result.substring(1) : result;
}

String variableNameToText(String variable) {
  String str = "";
  for (var c in variable.split("").indexed) {
    if (c.$1 > 0 && c.$2 == c.$2.toUpperCase()) {
      str += " ";
    }
    str += c.$2;
  }
  return str;
}

String resourceNameUri(Uri uri) {
  return uri.pathSegments.lastWhere((v) => v.isNotEmpty);
}

String resourceName(String path, {String pathSeparator = "/"}) {
  return path.split(pathSeparator).lastWhere((v) => v.isNotEmpty);
}
