import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/signup_screen.dart';

class Constants{



  String fillTemplate(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }


  Future<bool> checkAndRequestPermissions() async {
    // Android
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 13+ → no permission needed for saving images
      if (sdkInt >= 33) {
        return true;
      }

      // Android 10–12 → no permission needed
      if (sdkInt >= 29) {
        return true;
      }

      // Android 9 and below → storage permission required
      final status = await Permission.storage.request();
      return status.isGranted;
    }

    // iOS
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted;
    }

    return false;
  }




  Future<File> bytesToFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await file.writeAsBytes(bytes);
    print("save image at : ${file.path}");
    return file;
  }



}

void showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.only(top: 30),
        title: Column(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Log Out",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out? You will need to enter your credentials again to sign in.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        actions: [
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              // Logout Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    var pref = await SharedPreferences.getInstance();
                    pref.clear();
                    Get.offAll(() => SignUpScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Log Out",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
