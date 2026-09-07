import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'text_recognition_service.dart';

class MlKitTextRecognitionService implements TextRecognitionService {
  @override
  Future<List<RecognizedLine>> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            RecognizedLine(text: line.text, boundingBox: line.boundingBox),
      ];
    } finally {
      await recognizer.close();
    }
  }
}
