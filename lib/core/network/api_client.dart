import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiClient {
  final http.Client _client;
  String? _token;
  static const _timeout = Duration(seconds: 30);

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get currentHeaders => _headers;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<http.Response> get(String path) async {
    return _client.get(
      Uri.parse('${ApiConstants.baseUrl}$path'),
      headers: _headers,
    ).timeout(_timeout, onTimeout: () => http.Response('{"error":"timeout"}', 408));
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return _client.post(
      Uri.parse('${ApiConstants.baseUrl}$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout, onTimeout: () => http.Response('{"error":"timeout"}', 408));
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    return _client.put(
      Uri.parse('${ApiConstants.baseUrl}$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout, onTimeout: () => http.Response('{"error":"timeout"}', 408));
  }
}
