// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import 'auth_service.dart';

class FavoritesService extends ChangeNotifier {
  // Singleton
  static final FavoritesService instance = FavoritesService._();
  FavoritesService._();

  final _api = ApiClient();

  /// Conjunto com os documentIds dos parques favoritados
  final Set<String> _docIds = {};

  /// IDs com toggle em andamento — evita double-tap corrompendo estado
  final Set<String> _pending = {};

  List<String> get parkDocumentIds => _docIds.toList(growable: false);
  bool isFavoriteByDoc(String documentId) => _docIds.contains(documentId);
  bool isPending(String documentId) => _pending.contains(documentId);

  /// Inicializa: carrega favoritos do usuário autenticado
  Future<void> init() async {
    // Usa o cache síncrono — evita HTTP extra só para verificar auth
    final token = AuthService.instance.tokenSync;
    final me = AuthService.instance.currentUser;

    _docIds.clear();

    if (token == null || me == null) {
      notifyListeners();
      return;
    }

    await _loadFromServer();
  }

  Future<void> _loadFromServer() async {
    try {
      final r = await _api.get('/favorites/mine');
      if (r.statusCode == 200) {
        _parseMineResponse(r.body);
        notifyListeners();
      } else {
        if (kDebugMode) print('❌ FAV LOAD (${r.statusCode}): ${r.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ FAV LOAD network: $e');
    }
  }

  void _parseMineResponse(String body) {
    try {
      final jsonMap = jsonDecode(body);
      final List data = (jsonMap['data'] ?? []) as List;

      // Só limpa depois de confirmar que o parse foi bem-sucedido
      final newIds = <String>{};
      for (final item in data) {
        if (item is! Map) continue;
        final parkData = item['park'] as Map<String, dynamic>?;
        if (parkData != null) {
          final docId = parkData['documentId'] as String?;
          if (docId != null && docId.isNotEmpty) {
            newIds.add(docId);
          }
        }
      }

      _docIds
        ..clear()
        ..addAll(newIds);
    } catch (e) {
      if (kDebugMode) print('❌ Erro no _parseMineResponse: $e');
      // Não limpa _docIds — mantém estado anterior em caso de resposta inválida
    }
  }

  /// Alterna favorito por **documentId**.
  /// Retorna silenciosamente se já há uma requisição em andamento para o mesmo parque.
  Future<void> toggleByDocumentId(String parkDocumentId) async {
    // Guard de race condition: ignora tap duplo enquanto a requisição estiver em voo
    if (_pending.contains(parkDocumentId)) return;

    if (AuthService.instance.tokenSync == null) return;

    final wasFav = _docIds.contains(parkDocumentId);

    // Atualização otimista
    _pending.add(parkDocumentId);
    if (wasFav) {
      _docIds.remove(parkDocumentId);
    } else {
      _docIds.add(parkDocumentId);
    }
    notifyListeners();

    try {
      final res = await _api.post(
        '/favorites/toggle',
        body: {'parkDocumentId': parkDocumentId},
      );

      if (res.statusCode != 200) {
        if (wasFav) {
          _docIds.add(parkDocumentId);
        } else {
          _docIds.remove(parkDocumentId);
        }
        notifyListeners();
        if (kDebugMode) print('❌ FAV TOGGLE (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      // Reverte em erro de rede
      if (wasFav) {
        _docIds.add(parkDocumentId);
      } else {
        _docIds.remove(parkDocumentId);
      }
      notifyListeners();
      if (kDebugMode) print('❌ FAV TOGGLE network: $e');
    } finally {
      _pending.remove(parkDocumentId);
      notifyListeners(); // libera o isPending e reconstrói o botão
    }
  }
}