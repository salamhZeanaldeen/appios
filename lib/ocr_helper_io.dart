import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_helper.dart';

class IoOcrHelper implements OcrHelper {
  @override
  Future<String> recognizeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      // Explicitly use Arabic script for the user's requirement
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.arabic);
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      
      await textRecognizer.close();
      return text;
    } catch (e) {
      print('Native OCR Error: $e');
      return 'خطأ في استخراج النص: $e';
    }
  }
}

OcrHelper getOcrHelper() => IoOcrHelper();
