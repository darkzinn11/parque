// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const String kApiBase = 'http://192.168.15.12:1337/api';

class FavoritesService extends ChangeNotifier {
  // Singleton
  static final FavoritesService instance = FavoritesService._();
  FavoritesService._();

  /// Conjunto com os documentIds dos parques favoritados
  final Set<String> _docIds = {};
  List<String> get parkDocumentIds => _docIds.toList(growable: false);
  bool isFavoriteByDoc(String documentId) => _docIds.contains(documentId);

  /// Inicializa: carrega favoritos do usuário autenticado
  Future<void> init() async {
    final token = await AuthService.instance.token();
    final me = await AuthService.instance.me();

    _docIds.clear();

    if (token == null || me == null) {
      notifyListeners();
      return;
    }

    await _loadFromServer(token);
  }

  /// Carrega usando a rota custom /favorites/mine (sem filtros na query)
  Future<void> _loadFromServer(String token) async {
    // 1) tenta /favorites/mine
    final uMine = Uri.parse('$kApiBase/favorites/mine');
    try {
      final r1 = await http.get(uMine, headers: {'Authorization': 'Bearer $token'});
      if (r1.statusCode == 200) {
        _parseMineResponse(r1.body);
        notifyListeners();
        return;
      } else {
        if (kDebugMode) print('❌ FAV LOAD (mine ${r1.statusCode}): ${r1.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ FAV LOAD (mine) network: $e');
    }

    // 2) fallback (O seu código de fallback)
    try {
      final me = await AuthService.instance.me();
      final meId = me?['id'];
      if (meId == null) return;

      final u = Uri.parse('$kApiBase/favorites').replace(queryParameters: {
        'populate': 'park',
        'filters[user][id][\$eq]': '$meId',
        'pagination[pageSize]': '100',
      });

      final r2 = await http.get(u, headers: {'Authorization': 'Bearer $token'});
      if (r2.statusCode == 200) {
        // Usa o mesmo parser corrigido
        _parseMineResponse(r2.body);
        notifyListeners();
      } else {
        if (kDebugMode) print('❌ FAV LOAD (fallback ${r2.statusCode}): ${r2.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ FAV LOAD (fallback) network: $e');
    }
  }

  /// Parser robusto para /favorites/mine (transformResponse do Strapi v5)
  void _parseMineResponse(String body) {
    _docIds.clear();
    try {
      final jsonMap = jsonDecode(body);
      final List data = (jsonMap['data'] ?? []) as List;

      for (final item in data) {
        if (item is! Map) continue;

        // --- CORREÇÃO AQUI ---
        // O seu controller (favorite.ts) retorna a lista de favoritos
        // E o 'transformResponse' remove o 'attributes' do *favorito*,
        // mas não do 'park' que está dentro dele.
        
        // 1. Acessa o objeto 'park' (que foi populado)
        // (O 'item' não tem 'attributes' por causa do transformResponse)
        final parkData = item['park'] as Map<String, dynamic>?;
        
        // 2. Acessa o 'documentId' dentro do 'park'
        if (parkData != null) {
          final docId = parkData['documentId'] as String?;
          if (docId != null && docId.isNotEmpty) {
            _docIds.add(docId);
            print('✅ FAV PARSE: Encontrado park $docId'); // Log de sucesso
          }
        }
        // --- FIM DA CORREÇÃO ---
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro no _parseMineResponse: $e');
    }
  }

  /// Alterna favorito por **documentId** usando a rota custom do backend
  Future<void> toggleByDocumentId(String parkDocumentId) async {
    final token = await AuthService.instance.token();
    if (token == null) return;

    final wasFav = _docIds.contains(parkDocumentId);

    // Atualização otimista
    if (wasFav) {
      _docIds.remove(parkDocumentId);
    } else {
      _docIds.add(parkDocumentId);
    }
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kApiBase/favorites/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'parkDocumentId': parkDocumentId}),
      );

      if (res.statusCode != 200) {
        // Reverte se falhar
        if (wasFav) _docIds.add(parkDocumentId);
        else _docIds.remove(parkDocumentId);
        notifyListeners();
        if (kDebugMode) print('❌ FAV TOGGLE (${res.statusCode}): ${res.body}');
      } else {
        if (kDebugMode) print('✅ FAV TOGGLE ok: ${res.body}');
      }
    } catch (e) {
      // Reverte em erro de rede
      if (wasFav) _docIds.add(parkDocumentId);
      else _docIds.remove(parkDocumentId);
      notifyListeners();
      if (kDebugMode) print('❌ FAV TOGGLE network: $e');
    }
  }
}