import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Renders an image from a local file path on BOTH mobile and web.
///
/// On web, image_picker returns `blob:` URLs. Those can be shown directly by
/// `Image.network` — while `dart:io` `File` (used by `Image.file`) does not
/// exist on web and throws "Unsupported operation". On mobile we keep the
/// original `Image.file` behavior (fast, no network round trip).
Widget fileImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  Color? color,
  Alignment alignment = Alignment.center,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  if (kIsWeb) {
    return Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      color: color,
      alignment: alignment,
      errorBuilder: errorBuilder ?? _blank,
    );
  }
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    color: color,
    alignment: alignment,
    errorBuilder: errorBuilder ?? _blank,
  );
}

/// Like [fileImage] but returns an [ImageProvider] for use in
/// `DecorationImage`, `CircleAvatar`, etc.
ImageProvider fileImageProvider(String path) {
  if (kIsWeb) return NetworkImage(path);
  return FileImage(File(path));
}

/// Reads the bytes of a local file on both platforms. Mobile: reads from
/// disk. Web: fetches the blob URL. Prefer keeping the picked [XFile] around
/// and calling `XFile.readAsBytes()` directly — it also carries a real
/// filename, which the backend needs for extension detection.
Future<List<int>> readFileBytes(String path) async {
  if (kIsWeb) {
    final resp = await http.get(Uri.parse(path));
    return resp.bodyBytes;
  }
  return File(path).readAsBytes();
}

Widget _blank(BuildContext context, Object error, StackTrace? stack) =>
    const SizedBox.shrink();
