import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stub/util/image_orientation.dart';

void main() {
  test('bakes a rotated EXIF orientation into the pixels, producing an upright image', () async {
    // A 4x2 source image tagged with EXIF orientation 6 ("rotate 90°
    // clockwise to display upright") — mirrors a real portrait photo
    // whose sensor data is stored landscape with a rotation flag, which
    // is exactly what ML Kit doesn't reliably undo on its own.
    final source = img.Image(width: 4, height: 2);
    source.exif.imageIfd.orientation = 6;
    final tempDir = await Directory.systemTemp.createTemp('image_orientation_test');
    final inputPath = '${tempDir.path}/input.jpg';
    await File(inputPath).writeAsBytes(img.encodeJpg(source));

    final outputPath = await normalizeImageOrientation(inputPath);

    final result = img.decodeImage(await File(outputPath).readAsBytes())!;
    // Orientation 6 rotates 90°, so the baked-in upright image has its
    // width/height swapped relative to the raw source.
    expect(result.width, 2);
    expect(result.height, 4);
    // Orientation is now baked into the pixels — no rotation left to apply.
    final orientation = result.exif.imageIfd.orientation;
    expect(orientation == null || orientation == 1, isTrue);

    await tempDir.delete(recursive: true);
  });

  test('returns the original path unchanged when the file does not exist', () async {
    final outputPath = await normalizeImageOrientation('/no/such/file.jpg');
    expect(outputPath, '/no/such/file.jpg');
  });

  test('returns the original path unchanged when the file cannot be decoded as an image', () async {
    final tempDir = await Directory.systemTemp.createTemp('image_orientation_test');
    final notAnImagePath = '${tempDir.path}/not_an_image.jpg';
    await File(notAnImagePath).writeAsBytes([1, 2, 3]);

    final outputPath = await normalizeImageOrientation(notAnImagePath);

    expect(outputPath, notAnImagePath);
    await tempDir.delete(recursive: true);
  });
}
