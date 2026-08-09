import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';

/// Centralized image cropper settings to avoid duplication across the app
class ImageCropUtils {
  // Android crop settings
  static AndroidUiSettings getAndroidSettings(bool isDark) {
    return AndroidUiSettings(
      toolbarTitle: 'Edit Photo',
      toolbarColor: isDark ? const Color(0xFF0B0B0D) : Colors.white,
      toolbarWidgetColor: isDark ? Colors.white : Colors.black,
      statusBarColor: isDark ? const Color(0xFF0B0B0D) : Colors.white,
      backgroundColor: const Color(0xFF0B0B0D),
      activeControlsWidgetColor: const Color(0xFF10B981), // C.green
      dimmedLayerColor: Colors.black.withValues(alpha: 0.75),
      cropFrameColor: const Color(0xFF10B981), // C.green
      cropGridColor: Colors.white.withValues(alpha: 0.4),
      cropFrameStrokeWidth: 2,
      cropGridStrokeWidth: 1,
      cropStyle: CropStyle.rectangle,
      showCropGrid: true,
      hideBottomControls: false,
      initAspectRatio: CropAspectRatioPreset.original,
      lockAspectRatio: false,
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
        CropAspectRatioPreset.ratio3x2
      ],
    );
  }

  // iOS crop settings
  static IOSUiSettings getIOSSettings() {
    return IOSUiSettings(
      title: 'Edit Photo',
      doneButtonTitle: 'Done',
      cancelButtonTitle: 'Cancel',
      cropStyle: CropStyle.rectangle,
      aspectRatioLockEnabled: false,
      resetAspectRatioEnabled: true,
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
        CropAspectRatioPreset.ratio3x2
      ],
    );
  }

  // Get all UI settings for crop
  static List<PlatformUiSettings> getAllSettings(
      bool isDark, BuildContext context) {
    return [
      getAndroidSettings(isDark),
      getIOSSettings(),
      WebUiSettings(context: context),
    ];
  }
}
