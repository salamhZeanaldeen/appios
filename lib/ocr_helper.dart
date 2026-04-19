export 'ocr_helper_io.dart'
    if (dart.library.html) 'ocr_helper_web.dart';

abstract class OcrHelper {
  Future<String> recognizeText(String imagePath);
}
