import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';
import 'document_provider.dart';
import 'package:provider/provider.dart';
import 'notification_manager.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late Map<String, dynamic> _currentDoc;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDownloading = false;

  late TextEditingController _titleController;
  late String _currentStatus;
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _currentDoc = Map.from(widget.doc);
    _titleController = TextEditingController(text: _currentDoc['title']);
    _currentStatus = _currentDoc['status'] ?? 'في الانتظار';
    if (_currentDoc['status'] == 'قيد الانتظار') _currentStatus = 'في الانتظار'; // Migration
    if (_currentDoc['status'] == 'تم الرد' || _currentDoc['status'] == 'مؤرشف') _currentStatus = 'تم الإنجاز'; // Migration
    
    if (_currentDoc['deadline'] != null) {
      _selectedDeadline = DateTime.parse(_currentDoc['deadline']);
    }
  }

  Future<void> _markAsDone() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    try {
      await provider.updateDocument(_currentDoc['id'], {
        'status': 'تم الإنجاز',
      });
      await NotificationManager().cancelNotification(_currentDoc['id']);
      
      setState(() {
        _currentDoc['status'] = 'تم الإنجاز';
        _currentStatus = 'تم الإنجاز';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنجاز المراسلة وإلغاء التنبيهات')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareFile(String localPath) async {
    setState(() => _isDownloading = true);
    try {
      if (await File(localPath).exists()) {
        await Share.shareXFiles([XFile(localPath)], text: 'مشاركة مراسلة: ${_currentDoc['title']}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير موجود محلياً')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في المشاركة: $e')));
    } finally {
      setState(() => _isDownloading = false);
    }
  }


  Future<void> _save() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    
    try {
      await provider.updateDocument(_currentDoc['id'], {
        'title': _titleController.text,
        'status': _currentStatus,
        'deadline': _selectedDeadline?.toIso8601String(),
        'alert_at': _selectedDeadline != null ? _selectedDeadline!.subtract(const Duration(hours: 24)).toIso8601String() : null,
      });

      // Handle Notifications
      if (_currentStatus == 'تم الإنجاز') {
        await NotificationManager().cancelNotification(_currentDoc['id']);
      } else if (_selectedDeadline != null) {
        await NotificationManager().scheduleDeadlineAlert(
          id: _currentDoc['id'],
          title: _titleController.text,
          deadline: _selectedDeadline!,
        );
      }

      setState(() {
        _currentDoc['title'] = _titleController.text;
        _currentDoc['status'] = _currentStatus;
        _currentDoc['deadline'] = _selectedDeadline?.toIso8601String();
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات والجدولة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ المحلي: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المراسلة'),
          content: const Text('هل أنت متأكد من حذف هذه المراسلة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      await provider.deleteDocument(_currentDoc['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المراسلة من أرشيفك المحمول')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localImagePath = _currentDoc['image_path'] as String;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: _isEditing 
            ? const Text('تعديل البيانات') 
            : Text(_currentDoc['title'] ?? 'تفاصيل المراسلة'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (!_isEditing) ...[
              if (_isDownloading)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                IconButton(onPressed: () => _shareFile(localImagePath), icon: const Icon(Icons.share_outlined, color: Colors.blueAccent)),
              ],
              if (_currentDoc['status'] != 'تم الإنجاز')
                IconButton(
                  onPressed: _isSaving ? null : _markAsDone, 
                  icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  tooltip: 'تم الإنجاز',
                ),
              IconButton(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit_note, color: Colors.white70)),
              IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
            ] else 
              IconButton(onPressed: _isSaving ? null : _save, icon: const Icon(Icons.check, color: Colors.greenAccent)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditing) _buildEditForm() else _buildImageViewer(localImagePath),
              const SizedBox(height: 24),
              _buildInfoGrid(context),
              const SizedBox(height: 24),
              _buildOCRSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('عنوان المراسلة', style: TextStyle(color: Colors.white60, fontSize: 12)),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 20),
          const Text('الحالة', style: TextStyle(color: Colors.white60, fontSize: 12)),
          DropdownButton<String>(
            value: _currentStatus,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            items: ['في الانتظار', 'تم الإنجاز', 'تأجيل لموعد جديد'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (val) async {
              setState(() => _currentStatus = val!);
              if (val == 'تأجيل لموعد جديد') {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDeadline ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  helpText: 'اختر الموعد الجديد',
                );
                if (picked != null) setState(() => _selectedDeadline = picked);
              }
            },
          ),
          const SizedBox(height: 20),
          const Text('الموعد النهائي', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _selectedDeadline != null ? intl.DateFormat('yyyy/MM/dd').format(_selectedDeadline!) : 'لا يوجد',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.calendar_month, color: Colors.blueAccent),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDeadline ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDeadline = picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer(String localPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: InteractiveViewer(
        maxScale: 5.0,
        child: Image.file(
          File(localPath),
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200, color: Colors.white10, 
            child: const Center(child: Icon(Icons.broken_image, color: Colors.white24))
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _infoCard('النوع', _currentDoc['type'] ?? 'غير محدد', Icons.category_outlined),
        _infoCard('الحالة', _currentDoc['status'] ?? 'غير محدد', Icons.info_outline),
        _infoCard('التاريخ', _formatDate(_currentDoc['created_at']), Icons.calendar_today_outlined),
        _infoCard(
          'الموعد النهائي', 
          _currentDoc['deadline'] != null ? _formatDate(_currentDoc['deadline']) : 'لا يوجد', 
          Icons.timer_outlined,
          isUrgent: _currentDoc['deadline'] != null,
        ),
      ],
    );
  }

  Widget _buildOCRSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('النص المستخرج (OCR):', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: SelectableText(
            _currentDoc['ocr_text'] ?? 'جاري المعالجة...',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, {bool isUrgent = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isUrgent ? Colors.orangeAccent : Colors.white38),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            Text(value, style: TextStyle(color: isUrgent ? Colors.orangeAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ])),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return intl.DateFormat('yyyy/MM/dd').format(dt);
    } catch (e) { return dateStr; }
  }
}
