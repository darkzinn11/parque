// lib/core/api/api_config.dart

class ApiConfig {
  /// URL base para o novo backend em Go
  static const String baseUrl = 'https://apps.sitw.com.br/backend-park/api/v1';

  /// Timeouts e configurações de rede
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Headers padrão
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
