import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  static const String apiKey = "SOVEREIGN_SECRET_2026";

  ApiService({required this.baseUrl});

  Map<String, String> get headers => {
    'X-API-Key': apiKey,
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/stats'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load stats');
    }
  }

  Future<List<dynamic>> getDocuments({String? query}) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/documents',
      queryParameters: query != null ? {'q': query} : null,
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load documents');
    }
  }

  Future<bool> uploadDocument({
    required String title,
    required String type,
    required File file,
    String? deadline,
    String? alertAt,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents'));
    request.headers.addAll(headers);
    
    request.fields['title'] = title;
    request.fields['type'] = type;
    if (deadline != null) {
      request.fields['deadline'] = deadline;
    }
    if (alertAt != null) {
      request.fields['alert_at'] = alertAt;
    }

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
    ));

    final response = await request.send();
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateDocument({
    required int id,
    String? title,
    String? status,
    String? deadline,
    String? alertAt,
  }) async {
    var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/documents/$id'));
    request.headers.addAll(headers);
    
    if (title != null) request.fields['title'] = title;
    if (status != null) request.fields['status'] = status;
    if (deadline != null) request.fields['deadline'] = deadline;
    if (alertAt != null) request.fields['alert_at'] = alertAt;

    final response = await request.send();
    return response.statusCode == 200;
  }

  Future<bool> deleteDocument(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/documents/$id'),
      headers: headers,
    );
    return response.statusCode == 200;
  }
}
