import 'ocr_helper.dart';

class WebOcrHelper implements OcrHelper {
  @override
  Future<String> recognizeText(String imagePath) async {
    // Web implementation placeholder
    return 'التعرف على النصوص متاح حالياً في نسخة الهاتف فقط.';
  }
}

OcrHelper getOcrHelper() => WebOcrHelper();
