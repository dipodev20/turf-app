import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

enum CropRatio { square, banner, flag }

class ImageCropUtils {
  static final _picker = ImagePicker();

  static Future<File?> pickAndCrop({
    required CropRatio ratio,
    String toolbarTitle = 'Crop Image',
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _crop(picked.path, ratio, toolbarTitle);
  }

  static Future<File?> _crop(String path, CropRatio ratio, String title) async {
    CropAspectRatio aspectRatio;

    switch (ratio) {
      case CropRatio.square:
        aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1);
        break;
      case CropRatio.banner:
        aspectRatio = const CropAspectRatio(ratioX: 16, ratioY: 9);
        break;
      case CropRatio.flag:
        aspectRatio = const CropAspectRatio(ratioX: 3, ratioY: 2);
        break;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFF0F0F1A),
          toolbarWidgetColor: Colors.white,
          backgroundColor: const Color(0xFF0A0A12),
          activeControlsWidgetColor: const Color(0xFF5B5BD6),
          dimmedLayerColor: const Color(0xCC000000),
          cropFrameColor: const Color(0xFF5B5BD6),
          cropGridColor: const Color(0x445B5BD6),
          showCropGrid: true,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.original,
          hideBottomControls: false,
        ),
      ],
    );

    if (cropped == null) return null;
    return File(cropped.path);
  }
}
