import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'local_storage_service.dart';
import 'document_provider.dart';
import 'notification_manager.dart';

import 'platform_helper.dart';
import 'ocr_helper.dart';

// Conditionally import ML Kit only on native to avoid web build errors
// We use dynamic and late initialization to keep the compiler happy.

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  dynamic _image; // Supports io.File on native, XFile on web
  String _title = '';
  String _type = 'وارد';
  String _ocrText = '';
  DateTime? _deadline;
  TimeOfDay? _alertTime;
  bool _isProcessing = false;
  bool _isUploading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          // Absolute separation of types to satisfy compilers
          if (kIsWeb) {
            _image = pickedFile;
          } else {
            // We use dynamic to hide the type from the web compiler
            _image = pickedFile.path; 
          }
          _isProcessing = true;
        });
        
        if (!kIsWeb) {
          _processImage(pickedFile.path);
        } else {
          setState(() {
            _ocrText = 'التعرف الآلي متاح حالياً على نسخة الهاتف فقط. يرجى إدخال البيانات يدوياً.';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصورة: $e')));
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _image = result.files.single;
          } else {
            _image = result.files.single.path;
          }
          
          if (result.files.single.name.toLowerCase().endsWith('.pdf')) {
            _ocrText = 'تم اختيار ملف PDF. سيتم استخراج النصوص عند المعالجة.';
          } else if (!kIsWeb) {
            _isProcessing = true;
            _processImage(result.files.single.path!);
          } else {
            _ocrText = 'المسح الضوئي متاح على نسخة الهاتف. يرجى إدخال العنوان يدوياً.';
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في اختيار الملف: $e')));
    }
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          _deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  // Refactored to avoid all native types in the signature
  Future<void> _processImage(String path) async {
    if (kIsWeb) return;
    
    try {
      final helper = OcrHelper();
      final text = await helper.recognizeText(path);
      
      setState(() {
        _ocrText = text;
        // Try to extract a title from the first line if title is empty
        if (_title.isEmpty && text.isNotEmpty) {
          _title = text.split('\n').first.trim();
          if (_title.length > 50) _title = _title.substring(0, 47) + '...';
        }
      });
    } catch (e) {
      print('OCR Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveLocally() async {
    if (!_formKey.currentState!.validate() || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار صورة وإدخال العنوان')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isUploading = true);

    try {
      final storage = LocalStorageService();
      
      // Save image permanently
      final String localImagePath = await storage.saveImageLocally(_image);

      // Prepare document data
      final Map<String, dynamic> docData = {
        'title': _title,
        'type': _type,
        'status': _deadline != null ? 'قيد الانتظار' : 'مكتمل',
        'image_path': localImagePath,
        'ocr_text': _ocrText,
        'deadline': _deadline?.toIso8601String(),
        'alert_at': _deadline != null ? _deadline!.subtract(const Duration(hours: 24)).toIso8601String() : null,
      };

      final docProvider = Provider.of<DocumentProvider>(context, listen: false);
      await docProvider.addDocument(docData);

      if (_deadline != null && !kIsWeb) {
        await NotificationManager().scheduleDeadlineAlert(
          id: DateTime.now().millisecond,
          title: _title,
          deadline: _deadline!,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الحفظ في أرشيفك بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('إضافة مراسلة ذكية'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePreview(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _pickButton(Icons.photo_library, 'الاستوديو', () => _pickImage(ImageSource.gallery)),
                   _pickButton(Icons.upload_file, 'الملفات', _pickFile),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_ocrText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ملاحظة المعالجة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(_ocrText, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'العنوان', 
                  labelStyle: TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
                onSaved: (v) => _title = v ?? '',
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: const Text('الموعد النهائي للرد', style: TextStyle(fontSize: 14, color: Colors.white)),
                subtitle: Text(_deadline == null ? 'لم يتم التحديد' : intl.DateFormat('yyyy/MM/dd - HH:mm').format(_deadline!), style: const TextStyle(color: Colors.white70)),
                trailing: TextButton(onPressed: () => _selectDeadline(context), child: const Text('تغيير')),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isUploading || _isProcessing ? null : _saveLocally,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(16)),
                child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ في الأرشيف'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.camera),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: _image == null 
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: Colors.blueAccent),
                  SizedBox(height: 8),
                  Text('اضغط لتصوير المراسلة', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              )) 
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: getPlatformImage(kIsWeb ? (_image is String ? _image : _image.path) : _image.toString()),
              ),
      ),
    );
  }

  Widget _pickButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
