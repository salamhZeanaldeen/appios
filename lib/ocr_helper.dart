import 'ocr_helper_stub.dart'
    if (dart.library.html) 'ocr_helper_web.dart'
    if (dart.library.io) 'ocr_helper_io.dart';

abstract class OcrHelper {
  Future<String> recognizeText(String imagePath);
  factory OcrHelper() => getOcrHelper();
}
