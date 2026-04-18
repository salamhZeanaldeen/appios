import 'package:flutter/material.dart';
import 'local_storage_service.dart';

class DocumentProvider with ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();
  
  List<Map<String, dynamic>> _documents = [];
  Map<String, int> _stats = {
    'total': 0,
    'pending': 0,
    'incoming': 0,
    'outgoing': 0,
  };
  bool _isLoading = false;

  List<Map<String, dynamic>> get documents => _documents;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;

  Future<void> loadDocuments({String? query}) async {
    _isLoading = true;
    notifyListeners();

    _documents = await _storage.getAllDocuments(query: query);
    _stats = await _storage.getStats();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDocument(Map<String, dynamic> doc) async {
    await _storage.insertDocument(doc);
    await loadDocuments();
  }

  Future<void> updateDocument(int id, Map<String, dynamic> updates) async {
    await _storage.updateDocument(id, updates);
    await loadDocuments();
  }

  Future<void> deleteDocument(int id) async {
    await _storage.deleteDocument(id);
    await loadDocuments();
  }
}
