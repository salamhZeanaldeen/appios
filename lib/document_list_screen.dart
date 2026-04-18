import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'document_provider.dart';
import 'document_detail_screen.dart';

class DocumentListScreen extends StatefulWidget {
  final String title;
  final String? filterType;
  final String? filterStatus;

  const DocumentListScreen({
    super.key, 
    required this.title,
    this.filterType,
    this.filterStatus,
  });

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    // With DocumentProvider, documents are managed centrally.
    // We just filter them locally for this screen.
    final allDocs = Provider.of<DocumentProvider>(context, listen: false).documents;
    
    setState(() {
      _documents = allDocs.where((doc) {
        bool matchesType = widget.filterType == null || doc['type'] == widget.filterType;
        bool matchesStatus = widget.filterStatus == null || doc['status'] == widget.filterStatus;
        bool matchesSearch = _searchQuery.isEmpty || 
                            doc['title'].toString().contains(_searchQuery) ||
                            doc['ocr_text'].toString().contains(_searchQuery);
        return matchesType && matchesStatus && matchesSearch;
      }).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _fetch();
                },
                decoration: InputDecoration(
                  hintText: 'بحث في النتائج...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
            ? const Center(child: Text('لا توجد نتائج مطابقة'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _documents.length,
                itemBuilder: (context, i) {
                  final doc = _documents[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentDetailScreen(doc: doc)
                        ),
                      ).then((_) => _fetch()),
                      leading: CircleAvatar(
                        backgroundColor: doc['type'] == 'وارد' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        child: Icon(
                          doc['type'] == 'وارد' ? Icons.download : Icons.upload,
                          color: doc['type'] == 'وارد' ? Colors.blue : Colors.green,
                        ),
                      ),
                      title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الحالة: ${doc['status']}'),
                      trailing: const Icon(Icons.chevron_left),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
