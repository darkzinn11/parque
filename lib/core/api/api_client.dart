// lib/core/api/api_client.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Helper para construir a URL completa
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final url = '${ApiConfig.baseUrl}/$cleanPath';
    
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return Uri.parse(url).replace(
        queryParameters: queryParameters.map((key, value) => MapEntry(key, value.toString())),
      );
    }
    return Uri.parse(url);
  }

  /// Recupera headers com token se disponível
  Future<Map<String, String>> _getHeaders() async {
    final headers = ApiConfig.defaultHeaders;
    final token = await AuthService.instance.token();
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async {
    final uri = _buildUri(path, query);
    final headers = await _getHeaders();
    
    if (kDebugMode) print('🚀 [GET] $uri');
    
    return _client.get(uri, headers: headers);
  }

  Future<http.Response> post(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _getHeaders();
    
    if (kDebugMode) print('🚀 [POST] $uri');

    return _client.post(
      uri, 
      headers: headers, 
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _getHeaders();
    
    if (kDebugMode) print('🚀 [PUT] $uri');

    return _client.put(
      uri, 
      headers: headers, 
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _getHeaders();
    
    if (kDebugMode) print('🚀 [PATCH] $uri');

    return _client.patch(
      uri, 
      headers: headers, 
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path) async {
    final uri = _buildUri(path);
    final headers = await _getHeaders();
    
    if (kDebugMode) print('🚀 [DELETE] $uri');
    
    return _client.delete(uri, headers: headers);
  }
}
