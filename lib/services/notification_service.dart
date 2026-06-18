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
import '../data/models/app_notification.dart';
import '../firebase_options.dart';
import '../providers/notification_provider.dart';
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
  void Function(String route)? onDeepLink;

  /// Callback para exibir toast quando app está em foreground.
  /// Recebe título e corpo da notificação.
  void Function(String title, String body)? onForegroundToast;

  /// Provider onde as notificações são salvas.
  /// Registrado pelo main.dart após o MultiProvider estar montado.
  NotificationProvider? notificationProvider;

  /// Remove o token deste dispositivo do backend (chamado no logout).
  Future<void> deleteTokenOnLogout() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _api.delete('me/fcm-token', body: {'token': token});
      if (kDebugMode) print('🗑️ FCM token removido do backend');
    } catch (e) {
      if (kDebugMode) print('⚠️ Falha ao remover token FCM no logout: $e');
    }
  }

  /// Força o reenvio do token FCM ao backend.
  Future<void> saveTokenAfterLogin() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) print('🔑 FCM token (pós-login): $token');
      if (token != null) {
        await _saveToken(token);
      } else {
        if (kDebugMode) print('⚠️ FCM token nulo — permissão de notificação provavelmente negada no iOS');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ FCM getToken falhou: $e');
    }
  }

  /// Inicializa o Firebase + FCM de forma segura.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Inscreve no tópico de anúncios — recebe broadcasts de eventos do parque.
      await messaging.subscribeToTopic('parque-todos');

      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // App em foreground: salva no inbox e mostra toast.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // App aberto a partir do toque na notificação.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // App estava terminado e foi aberto pela notificação.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleMessageOpened(initial);

      // Registra o token e escuta refreshes.
      final token = await messaging.getToken();
      if (kDebugMode) print('🔑 FCM token: $token');
      if (token != null) await _saveToken(token);
      messaging.onTokenRefresh.listen(_saveToken);

      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('⚠️ FCM indisponível (config ausente): $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = _toAppNotification(message);
    if (notification == null) return;

    notificationProvider?.add(notification);
    onForegroundToast?.call(notification.title, notification.body);

    if (kDebugMode) print('📩 FCM foreground: ${notification.title}');
  }

  void _handleMessageOpened(RemoteMessage message) {
    final notification = _toAppNotification(message);
    if (notification != null) {
      notificationProvider?.add(notification);
    }

    final route = message.data['deeplink']?.toString();
    if (route != null && route.isNotEmpty) {
      onDeepLink?.call(route);
    }
  }

  AppNotification? _toAppNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty) return null;

    return AppNotification(
      id: NotificationProvider.generateId(),
      type: message.data['type']?.toString() ?? 'general',
      title: title,
      body: body ?? '',
      deeplink: message.data['deeplink']?.toString(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveToken(String token) async {
    try {
      if (!await AuthService.instance.isLogged()) return;
      await _api.post('me/fcm-token', body: {
        'token': token,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (e) {
      if (kDebugMode) print('⚠️ Falha ao salvar token FCM: $e');
    }
  }
}
