import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FilePickerField extends StatefulWidget {
  final Function(String) onTextSubmitted;
  final String? defaultContent;
  final Widget? iconOverride;

  const FilePickerField(
      {super.key,
      required this.onTextSubmitted,
      this.defaultContent,
      this.iconOverride});

  @override
  _FilePickerFieldState createState() => _FilePickerFieldState();
}

class _FilePickerFieldState extends State<FilePickerField> {
  final TextEditingController controller = TextEditingController();

  // MaterialButton(
  //   padding: EdgeInsets.zero,
  //   visualDensity: VisualDensity(horizontal: -4, vertical: -4),
  //   height: 10,
  //   minWidth: 10,
  //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //   onPressed: () {
  //     FilePicker.platform.getDirectoryPath().then((v) {
  //       if (v != null) {
  //         widget.configMap[ConfigField.installDir] = v;
  //         print(widget.configMap);
  //         setState(() {});
  //       }
  //     });
  //   },
  //   child: Icon(
  //     Icons.folder,
  //     opticalSize: 10,
  //   ),
  // ),

  @override
  void initState() {
    super.initState();
    controller.value = TextEditingValue(text: widget.defaultContent ?? "");
  }

  @override
  TextFormField build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(10);
    final InputDecoration inpd = InputDecoration(
        filled: false,
        border: OutlineInputBorder(borderRadius: borderRadius),
        isDense: true,
        isCollapsed: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        prefixIconConstraints: BoxConstraints.tight(const Size.square(30)),
        prefixIcon: ClipRRect(
            borderRadius: borderRadius,
            child: widget.iconOverride ??
                MaterialButton(
                    onPressed: () {
                      FilePicker.platform
                          .getDirectoryPath(initialDirectory: controller.text)
                          .then((v) {
                        if (v != null) {
                          controller.value = TextEditingValue(text: v);
                          setState(() {});
                          widget.onTextSubmitted(v);
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      Icons.folder,
                    ))));

    return TextFormField(
      controller: controller,
      onChanged: (t) {
        // setState(() {
        //   controller.value = TextEditingValue(text: t);
        // });
        widget.onTextSubmitted(t);
      },
      decoration: inpd,
    );
  }
}
