import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  static Database? _database;

  LocalStorageService._internal();

  factory LocalStorageService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sovereign_archive.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        image_path TEXT NOT NULL,
        ocr_text TEXT,
        deadline TEXT,
        alert_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Save image to permanent app storage
  Future<String> saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final String fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}${extension(imageFile.path)}';
    final String localPath = join(directory.path, fileName);
    
    final File localFile = await imageFile.copy(localPath);
    return localFile.path;
  }

  // CRUD Operations
  Future<int> insertDocument(Map<String, dynamic> doc) async {
    final db = await database;
    return await db.insert('documents', {
      ...doc,
      'created_at': doc['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllDocuments({String? query}) async {
    final db = await database;
    if (query != null && query.isNotEmpty) {
      return await db.query(
        'documents',
        where: 'title LIKE ? OR ocr_text LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query('documents', orderBy: 'created_at DESC');
  }

  Future<int> updateDocument(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'documents',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    // Note: In a production app, we should also delete the image file from disk
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final all = await db.query('documents');
    
    int total = all.length;
    int pending = all.where((d) => d['status'] == 'قيد الانتظار').length;
    int incoming = all.where((d) => d['type'] == 'وارد').length;
    int outgoing = all.where((d) => d['type'] == 'صادر').length;

    return {
      'total': total,
      'pending': pending,
      'incoming': incoming,
      'outgoing': outgoing,
    };
  }
}
