import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'local_storage_service.dart';
import 'document_provider.dart';
import 'notification_manager.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  File? _image;
  String _title = '';
  String _type = 'وارد';
  String _ocrText = '';
  DateTime? _deadline;
  TimeOfDay? _alertTime;
  bool _isProcessing = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isProcessing = true;
      });
      
      // Perform local OCR instantly
      _processImage(_image!);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _image = file;
        if (file.path.toLowerCase().endsWith('.pdf')) {
          _ocrText = 'تم اختيار ملف PDF. سيتم استخراج النصوص على السيرفر.';
        } else {
          _isProcessing = true;
          _processImage(file);
        }
      });
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

  Future<void> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      setState(() {
        _ocrText = recognizedText.text;
        _isProcessing = false;
      });
    } catch (e) {
      print('OCR Error: $e');
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
      
      // 1. Save image permanently in app documents directory
      final String localImagePath = await storage.saveImageLocally(_image!);

      // 2. Prepare document data
      final Map<String, dynamic> docData = {
        'title': _title,
        'type': _type,
        'status': _deadline != null ? 'قيد الانتظار' : 'مكتمل',
        'image_path': localImagePath,
        'ocr_text': _ocrText,
        'deadline': _deadline?.toIso8601String(),
        'alert_at': _deadline != null ? _deadline!.subtract(const Duration(hours: 24)).toIso8601String() : null,
      };

      // 3. Save to SQLite
      final docProvider = Provider.of<DocumentProvider>(context, listen: false);
      await docProvider.addDocument(docData);

      // 4. Schedule notification if deadline exists
      if (_deadline != null) {
        await NotificationManager().scheduleDeadlineAlert(
          id: DateTime.now().millisecond,
          title: _title,
          deadline: _deadline!,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الحفظ في أرشيفك المحلي بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ المحلي: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مراسلة ذكية')),
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
                      const Text('النص المستخرج محلياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(_ocrText, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                onSaved: (v) => _title = v ?? '',
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: const Text('الموعد النهائي للرد', style: TextStyle(fontSize: 14)),
                subtitle: Text(_deadline == null ? 'لم يتم التحديد' : intl.DateFormat('yyyy/MM/dd - HH:mm').format(_deadline!)),
                trailing: TextButton(onPressed: () => _selectDeadline(context), child: const Text('تغيير')),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isUploading || _isProcessing ? null : _saveLocally,
                child: _isUploading ? const CircularProgressIndicator() : const Text('حفظ في الأرشيف المحلي'),
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
            : _image!.path.toLowerCase().endsWith('.pdf')
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 64, color: Colors.redAccent),
                    SizedBox(height: 8),
                    Text('تم اختيار ملف PDF', style: TextStyle(color: Colors.white70)),
                  ],
                ))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(_image!, fit: BoxFit.contain)
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
