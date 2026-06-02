// lib/services/notification_service.dart
//
// Push notifications via Firebase Cloud Messaging.
//
// Graceful degradation: toda a inicialização é protegida por try/catch. Se o
// projeto Firebase ainda não estiver configurado (faltando google-services.json
// / GoogleService-Info.plist), o app NÃO quebra — apenas o push fica inativo.
// Assim que os arquivos de config forem adicionados, o push passa a funcionar
// sem mudar código.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../services/auth_service.dart';

/// Handler de mensagens em background (precisa ser top-level).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Nada a fazer em background além de deixar o SO exibir a notificação.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ApiClient _api = ApiClient();
  bool _initialized = false;

  /// Callback que a camada de navegação registra para tratar deep links.
  /// Recebe a rota (ex: "/tabs/user/minhas-reservas").
  void Function(String route)? onDeepLink;

  /// Inicializa o Firebase + FCM de forma segura.
  /// Deve ser chamado após o login (quando há usuário autenticado).
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // App em foreground: repassa o deep link se houver.
      FirebaseMessaging.onMessage.listen((msg) {
        // Notificação em foreground é tratada pela UI (toast) se desejado.
        if (kDebugMode) print('📩 FCM foreground: ${msg.notification?.title}');
      });

      // App aberto a partir do toque na notificação.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleDeepLink);

      // App estava terminado e foi aberto pela notificação.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleDeepLink(initial);

      // Registra o token e escuta refreshes.
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
      messaging.onTokenRefresh.listen(_saveToken);

      _initialized = true;
    } catch (e) {
      // Firebase não configurado ainda — segue sem push.
      if (kDebugMode) print('⚠️ FCM indisponível (config ausente): $e');
    }
  }

  void _handleDeepLink(RemoteMessage message) {
    final route = message.data['deeplink']?.toString();
    if (route != null && route.isNotEmpty) {
      onDeepLink?.call(route);
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      if (!await AuthService.instance.isLogged()) return;
      await _api.post('me/fcm-token', body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (e) {
      if (kDebugMode) print('⚠️ Falha ao salvar token FCM: $e');
    }
  }
}
