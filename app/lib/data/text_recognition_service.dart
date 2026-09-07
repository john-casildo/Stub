import 'dart:ui';

/// One line of text recognized in an image, with its position — enough
/// for `receipt_parser.dart`'s position-based reconstruction, not the
/// full API surface of whichever OCR engine produced it.
class RecognizedLine {
  const RecognizedLine({required this.text, required this.boundingBox});

  final String text;
  final Rect boundingBox;

  @override
  bool operator ==(Object other) =>
      other is RecognizedLine && other.text == text && other.boundingBox == boundingBox;

  @override
  int get hashCode => Object.hash(text, boundingBox);
}

abstract class TextRecognitionService {
  Future<List<RecognizedLine>> recognizeText(String imagePath);
}
