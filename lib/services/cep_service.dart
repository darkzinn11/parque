import 'dart:convert';
import 'package:http/http.dart' as http;

class CepResult {
  final String cep;
  final String logradouro;
  final String bairro;
  final String localidade;
  final String uf;

  const CepResult({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.localidade,
    required this.uf,
  });
}

class CepService {
  CepService._();

  /// Busca endereço pelo CEP usando ViaCEP.
  /// Retorna null se CEP inválido, não encontrado ou sem conexão.
  static Future<CepResult?> fetch(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return null;

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['erro'] == true || data['erro'] == 'true') return null;

      return CepResult(
        cep: data['cep']?.toString() ?? '',
        logradouro: data['logradouro']?.toString() ?? '',
        bairro: data['bairro']?.toString() ?? '',
        localidade: data['localidade']?.toString() ?? '',
        uf: data['uf']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
