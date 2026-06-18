import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _api = ApiClient();

  // STORAGE
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'park_jwt_token'; // Alterado para evitar conflito com o antigo

  String? _tokenCache;
  Map<String, dynamic>? _userCache;

  // ======================================================
  // INIT
  // ======================================================
  Future<void> init() async {
    _tokenCache = await _storage.read(key: _tokenKey);
    if (_tokenCache != null) {
      await refreshUser();
    }
    notifyListeners();
  }

  // GETTERS
  String? get tokenSync => _tokenCache;
  Map<String, dynamic>? get currentUser => _userCache;
  String? get userId => _userCache?['id']?.toString();

  // ======================================================
  // LOGIN (Contrato Go)
  // ======================================================
  Future<bool> login(String email, String password) async {
    try {
      final res = await _api.post('/login', body: {
        'email': email,
        'senha': password,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        final user = data['usuario'];

        if (token != null) {
          _tokenCache = token;
          await _storage.write(key: _tokenKey, value: token);
          if (user != null) _userCache = user;

          notifyListeners();
          return true;
        }
      }

      if (kDebugMode) {
        print("❌ Login falhou: ${res.statusCode} -> ${res.body}");
      }
      return false;

    } catch (e) {
      if (kDebugMode) print("❌ Erro login: $e");
      return false;
    }
  }

  // ======================================================
  // ME / REFRESH USER (Contrato Go)
  // ======================================================
  Future<Map<String, dynamic>?> me() async {
    if (_tokenCache == null) return null;
    try {
      final res = await _api.get('/me');

      if (res.statusCode == 200) {
        final user = jsonDecode(res.body);
        _userCache = user;
        notifyListeners();
        return user;
      }

      // Token expirado ou inválido — limpa sessão localmente
      if (res.statusCode == 401) {
        await logout();
      }
    } catch (e) {
      if (kDebugMode) print("❌ Erro /me: $e");
    }
    return null;
  }
  
  Future<void> refreshUser() async {
    await me();
  }

  // ======================================================
  // LOGOUT
  // ======================================================

  /// Registrado pelo main.dart para evitar dependência circular com NotificationService.
  Future<void> Function()? onBeforeLogout;

  Future<void> logout() async {
    try {
      await onBeforeLogout?.call();
    } catch (_) {}
    _tokenCache = null;
    _userCache = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<String?> token() async {
    _tokenCache ??= await _storage.read(key: _tokenKey);
    return _tokenCache;
  }

  Future<bool> isLogged() async => (await token()) != null;

  /// Login direto com token já obtido (ex: após reset de senha).
  Future<void> loginWithToken(String token, Map<String, dynamic>? user) async {
    _tokenCache = token;
    await _storage.write(key: _tokenKey, value: token);
    if (user != null) _userCache = user;
    notifyListeners();
  }

  // ======================================================
  // SIGNUP (Contrato Go)
  // ======================================================
  Future<dynamic> signup({
    required String username,
    required String email,
    required String password,
    String? phone,
    String? cpf,
    String? cidade,
    String? cep,
    String? rua,
    String? numero,
    String? complemento,
    String? bairro,
  }) async {
    try {
      final res = await _api.post('/register', body: {
        'nome': username,
        'email': email,
        'senha': password,
        if (phone != null && phone.isNotEmpty) 'telefone': phone,
        if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
        if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
        if (cep != null && cep.isNotEmpty) 'cep': cep,
        if (rua != null && rua.isNotEmpty) 'rua': rua,
        if (numero != null && numero.isNotEmpty) 'numero': numero,
        if (complemento != null && complemento.isNotEmpty) 'complemento': complemento,
        if (bairro != null && bairro.isNotEmpty) 'bairro': bairro,
      });

      if (res.statusCode != 200 && res.statusCode != 201) {
        final j = jsonDecode(res.body);
        return j["error"] ?? "Falha ao cadastrar";
      }

      final data = jsonDecode(res.body);
      final token = data['token'];
      final user = data['usuario'];

      if (token != null) {
        _tokenCache = token;
        await _storage.write(key: _tokenKey, value: token);
        if (user != null) _userCache = user;
        notifyListeners();
        return true;
      }

      return "Resposta inválida do servidor";

    } catch (e) {
      if (kDebugMode) print("❌ Erro signup: $e");
      return "Erro de rede";
    }
  }

  // ======================================================
  // ESQUECEU / RESET SENHA
  // ======================================================
  Future<bool> requestPasswordReset(String email) async {
    try {
      final res = await _api.post('/forgot-password', body: {'email': email});
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetPassword(String code, String newPass) async {
    try {
      final res = await _api.post('/reset-password', body: {
        'code': code,
        'password': newPass,
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}