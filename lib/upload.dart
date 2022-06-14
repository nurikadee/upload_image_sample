import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:upload_image_sample/preview.dart';
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';

class Upload extends StatefulWidget {
  const Upload({Key? key}) : super(key: key);

  @override
  State<Upload> createState() => _UploadState();
}

class _UploadState extends State<Upload> {
  File? fileSelected;
  int quality = 0;

  bool uploadInprogress = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Image Sample')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GestureDetector(
                onTap: () => selectImage(context),
                child: const Text(
                  "Select Image",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "File Selected : ${fileSelected?.path ?? ' N/A'}",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Preview(path: fileSelected?.path),
            Container(
              color: !uploadInprogress
                  ? const Color.fromARGB(255, 250, 146, 34)
                  : Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  if (!uploadInprogress) uploadImage(context);
                },
                child: Text(
                  uploadInprogress ? 'Uploading a image....' : "Upload Image",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  selectImage(context) async {
    var photoPermissionGrant = await requestPermissions(Permission.photos);
    if (photoPermissionGrant) {
      try {
        XFile? pickedFile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: quality,
        );
        if (pickedFile != null) {
          setState(() {
            quality = 95;
          });
          File convertFile = File(pickedFile.path);
          compressFile(convertFile);
        }
      } catch (error, stackTrace) {
        log('${error.toString()} ${stackTrace.toString()}');
      }
    } else {
      const snackBar = SnackBar(
        backgroundColor: Colors.red,
        content: Text('Permission Denied'),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  compressFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    if (file.lengthSync() <= 3145728) {
      setState(() {
        fileSelected = file;
      });
    } else {
      File? result = await (FlutterImageCompress.compressAndGetFile(
        file.path,
        outPath,
        quality: quality,
      ));

      if (result != null) {
        if (result.lengthSync() > 3145728 && quality > 30) {
          setState(() {
            quality -= 10;
          });
          compressFile(result);
        } else {
          setState(() {
            fileSelected = result;
          });
        }
      }
    }
  }

  Future<bool> requestPermissions(Permission permission) async {
    if (await permission.request().isGranted) {
      return true;
    } else {
      await [permission].request();
    }
    return false;
  }

  Future uploadImage(context) async {
    if (fileSelected != null) {
      Stream<List<int>> stream = fileSelected!.openRead();

      var length = await fileSelected!.length();

      var uri = Uri.parse("https://upload.uploadcare.com/base/");

      var request = MultipartRequest("POST", uri);

      request.fields["UPLOADCARE_PUB_KEY"] = "52cc49d16d1a07ed3d7f";
      request.fields["UPLOADCARE_STORE"] = "auto";

      var multipartFile = MultipartFile(
        'fileName',
        stream,
        length,
        filename: basename(fileSelected!.path),
        contentType: MediaType.parse(
            'image/${extension(fileSelected!.path).replaceAll('.', '')}'),
      );

      request.files.add(multipartFile);

      setState(() => uploadInprogress = true);

      await request.send().then((response) async {
        response.stream.transform(utf8.decoder).listen((value) {
          log(value);
          setState(() => uploadInprogress = false);

          var snackBar = SnackBar(
            backgroundColor:
                response.statusCode == 200 ? Colors.green : Colors.red,
            content: Text(response.statusCode == 200 ? 'Success' : 'Failed'),
          );

          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
      }).catchError((e) {
        log(e);
        setState(() => uploadInprogress = false);
      });
    } else {
      log('No file selected');
    }
  }
}
