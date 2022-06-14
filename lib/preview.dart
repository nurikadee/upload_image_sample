import 'dart:io';

import 'package:flutter/material.dart';

class Preview extends StatelessWidget {
  final String? path;
  const Preview({Key? key, this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return path != null
        ? SizedBox(width: 150, height: 150, child: Image.file(File('$path')))
        : const SizedBox();
  }
}
