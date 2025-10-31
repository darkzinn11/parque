import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Endereço da API do Strapi (ajuste para seu servidor/domínio real)
const String kApiBase = 'http://192.168.15.17:1337/api';

class AuthService extends ChangeNotifier {
  // ---------- SINGLETON ----------
  static final AuthService instance = AuthService._();
  AuthService._();

  // ---------- STORAGE ----------
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'strapi_jwt_token';

  String? _tokenCache;
  Map<String, dynamic>? _userCache;

  // ---------- INIT ----------
  Future<void> init() async {
    _tokenCache = await _storage.read(key: _tokenKey);
    if (_tokenCache != null) {
      _userCache = await me();
    }
    notifyListeners();
  }

  String? get tokenSync => _tokenCache;
  Map<String, dynamic>? get currentUser => _userCache;
  String? get userId => _userCache?['id']?.toString();

  // ---------- LOGIN ----------
  Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/local'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': email, // Strapi aceita email ou username
          'password': password,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['jwt'];
        if (token is String && token.isNotEmpty) {
          _tokenCache = token;
          await _storage.write(key: _tokenKey, value: token);
          _userCache = data['user'];
          notifyListeners();
          return true;
        }
      }

      if (kDebugMode) {
        print('❌ Falha login: ${res.statusCode} -> ${res.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Erro de rede no login: $e');
      return false;
    }
  }

  // ---------- LOGOUT ----------
  Future<void> logout() async {
    _tokenCache = null;
    _userCache = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  // ---------- TOKEN ----------
  Future<String?> token() async {
    _tokenCache ??= await _storage.read(key: _tokenKey);
    return _tokenCache;
  }

  // ---------- ME ----------
  Future<Map<String, dynamic>?> me() async {
    final t = await token();
    if (t == null) return null;
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/users/me'),
        headers: {'Authorization': 'Bearer $t'},
      );

      if (res.statusCode == 200) {
        final user = jsonDecode(res.body);
        _userCache = user;
        if (kDebugMode) print('🔑 Usuario logado: $user');
        return user;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao buscar /users/me: $e');
    }
    return null;
  }

  Future<bool> isLogged() async => (await token()) != null;

  // ---------- SIGNUP (2 passos: register + update) ----------
  Future<dynamic> signup({
    required String username,
    required String email,
    required String password,
    String? phone,
    String? cpf,
  }) async {
    try {
      // 1) cria usuário
      final res = await http.post(
        Uri.parse('$kApiBase/auth/local/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (kDebugMode) {
        print('📩 Signup step1 (${res.statusCode}): ${res.body}');
      }

      if (res.statusCode != 200) {
        try {
          final j = jsonDecode(res.body);
          if (j is Map && j['error'] is Map && j['error']['message'] is String) {
            return j['error']['message'];
          }
        } catch (_) {}
        return 'Falha ao cadastrar (${res.statusCode})';
      }

      final j1 = jsonDecode(res.body) as Map<String, dynamic>;
      final jwt = j1['jwt'] as String?;
      final user = j1['user'] as Map<String, dynamic>?;

      if (jwt == null || user == null) {
        return 'Resposta inesperada do servidor';
      }

      // salva cache/token
      _tokenCache = jwt;
      await _storage.write(key: _tokenKey, value: jwt);
      _userCache = user;

      // 2) atualiza extras (cpf/phone) se tiver
      final hasExtras = (phone != null && phone.isNotEmpty) || (cpf != null && cpf.isNotEmpty);
      if (hasExtras) {
        final upd = await http.put(
          Uri.parse('$kApiBase/users/${user['id']}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({
            if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        );

        if (kDebugMode) {
          print('📩 Signup step2 (${upd.statusCode}): ${upd.body}');
        }

        if (upd.statusCode == 200) {
          _userCache = jsonDecode(upd.body) as Map<String, dynamic>;
        } else {
          if (kDebugMode) {
            print('⚠️ Cadastro ok, mas update CPF/phone falhou '
                '(code ${upd.statusCode}). Verifique permissões.');
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Erro de rede no signup: $e');
      return 'Erro de rede ao cadastrar';
    }
  }

  // ---------- ESQUECEU SENHA ----------
  Future<bool> requestPasswordReset(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('❌ Erro de rede no requestPasswordReset: $e');
      return false;
    }
  }

  // ---------- RESET SENHA ----------
  Future<bool> resetPassword(String code, String newPass) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'password': newPass,
          'passwordConfirmation': newPass,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('❌ Erro de rede no resetPassword: $e');
      return false;
    }
  }
}
