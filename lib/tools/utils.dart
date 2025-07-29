import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'core/core.dart';

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

class Table<T> {
  Table();

  final Map<int, Map<int, T>> table = {};

  Table.fromMap(Map<dynamic, dynamic> jsonMap) {
    if (jsonMap is Map<int, Map<int, T>>) {
      this.table.addAll(jsonMap);
      return;
    }

    for (var mp in jsonMap.entries) {
      final row = mp.key;
      final value = mp.value;
      if (!row is int) {
        throw const FormatException("Row key can only be of type int");
      }
      if (!value is Map<dynamic, dynamic>) {
        throw const FormatException("Row value type can only be of type Map");
      }
      for (var mp2 in (value as Map<dynamic, dynamic>).entries) {
        final column = mp2.key;
        final value2 = mp2.value;
        if (!column is int) {
          throw const FormatException("Column key can only be of type int");
        }
        if (!value2 is T) {
          throw const FormatException("Cell value is not of the correct type");
        }
        insert(row, column, value2);
      }
    }
  }

  setRow(int row, List<T?> values) {
    for (var v in values.indexed) {
      final vv = v.$2;
      if (vv != null) {
        insert(row, v.$1, vv);
      }
    }
  }

  addRow(List<T?> values) {
    int startIndex = table.keys.maxOrNull ?? 0;
    setRow(startIndex + 1, values);
  }

  setColumn(int column, List<T?> values) {
    for (var v in values.indexed) {
      final vv = v.$2;
      if (vv != null) {
        insert(v.$1, column, vv);
      }
    }
  }

  List<T?> getRow(int row) {
    List<T?> rowData = [];
    final baseData = table[row] ?? {};
    for (int col = 0; col <= (baseData.keys.maxOrNull ?? 0); col++) {
      rowData.add(baseData[col]);
    }
    return rowData;
  }

  List<T?> getColumn(int column) {
    List<T?> col = [];
    for (var row in table.values) {
      final val = row[column];
      col.add(val);
    }
    return col;
  }

  T? insert(int row, int column, T value) {
    Map<int, T> rowContent = table[row] ?? {};
    final oldValue = rowContent[column];
    rowContent[column] = value;
    table[row] = rowContent;
    return oldValue;
  }

  T? get(int row, int column) {
    Map<int, T>? rowContent = table[row];
    if (rowContent == null) {
      return null;
    }
    return rowContent[column];
  }

  String toCsv() {
    String output = "";
    for (int row = 0; row <= (table.keys.maxOrNull ?? 0); row++) {
      final rowData = getRow(row);
      final line = rowData.isNotEmpty
          ? rowData.map((v) => v != null ? v.toString() : "").join(";")
          : ";;";
      output += "$line\n";
    }
    return output;
  }

  static Table<String> fromCsv(String csv) {
    Table<String> out = Table();
    for (var line in csv.split("\n").indexed) {
      int lineNumber = line.$1;
      String lineValue = line.$2;
      for (var v in lineValue.split(";").indexed) {
        if (v.$2.isNotEmpty) {
          out.insert(lineNumber, v.$1, v.$2);
        }
      }
    }

    return out;
  }
}

String cleanPath(String path) {
  final startClean =
      path.startsWith("/") || path.startsWith("\\") ? path.substring(1) : path;

  return startClean.endsWith("/") || startClean.endsWith("\\")
      ? startClean.substring(0, startClean.length - 1)
      : startClean;
}

Future<Directory?> searchTreeForRoot(Uri basePath) async {
  final s = Platform.pathSeparator;
  final segments = basePath.pathSegments;
  for (int i = segments.length; i > 0; i--) {
    final path =
        "${Platform.isWindows ? "" : s}${segments.sublist(0, i).join(s)}";
    final manPath = "$path$s${DirNames.fileManifest}";
    if (await File(manPath).exists()) {
      return Directory(path);
    }
  }
  return null;
}

String prettyTimePrint(DateTime dateTime,
    {bool forceFullDateDisplay = false,
    bool includeSeconds = true,
    String dateTimeSeparator = "at"}) {
  final String timeString =
      "${dateTime.hour.toString().padLeft(2, "0")}:${dateTime.minute.toString().padLeft(2, "0")}${includeSeconds ? ":${dateTime.second.toString().padLeft(2, "0")}" : ""}";
  final String dateString;
  if (forceFullDateDisplay ||
      (dateTime.difference(DateTime.now()).inHours >= 24 &&
          dateTime.day != DateTime.now().day)) {
    dateString =
        "${dateTime.day.toString().padLeft(2, "0")}/${dateTime.month.toString().padLeft(2, "0")}/${dateTime.year.toString().padLeft(4, "0")}";
  } else {
    dateString = "today";
  }
  return "$dateString $dateTimeSeparator $timeString";
}
