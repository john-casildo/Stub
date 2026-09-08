import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decode + bake-orientation + re-encode is genuinely CPU-heavy for a
/// full-resolution photo — run via `compute()` in [normalizeImageOrientation]
/// so it doesn't block the UI thread (this blocked the whole app,
/// including the loading spinner's own animation, for the duration of a
/// scan before it was moved off the main isolate). Must be a top-level
/// function: `compute` sends it to a new isolate.
Uint8List? _bakeOrientationSync(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Malformed/unsupported input — the decoder's format probing can
    // throw rather than return null.
    return null;
  }
  if (decoded == null) return null;
  return img.encodeJpg(img.bakeOrientation(decoded));
}

/// Bakes any EXIF orientation into the pixel data and writes the result
/// as a new upright JPEG, returning its path (the original file is left
/// untouched). ML Kit's text recognizer reads raw pixel buffers directly
/// and does not reliably apply EXIF orientation itself, so a receipt
/// photographed in portrait (very common) can otherwise be processed
/// rotated — degrading OCR accuracy and scrambling
/// `receipt_parser.dart`'s row-based reconstruction, which assumes
/// upright text.
Future<String> normalizeImageOrientation(String imagePath) async {
  Uint8List bytes;
  try {
    bytes = await File(imagePath).readAsBytes();
  } catch (_) {
    // Missing or unreadable file — fall back to the original path rather
    // than losing the scan.
    return imagePath;
  }
  final result = await compute(_bakeOrientationSync, bytes);
  if (result == null) return imagePath;
  final outPath = '$imagePath.oriented.jpg';
  await File(outPath).writeAsBytes(result);
  return outPath;
}
