import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'routes/app_router.dart';

// Serviços
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/notification_service.dart';
import 'services/run_tracker_service.dart';

// Providers
import 'providers/notification_provider.dart';
import 'widgets/app_toast.dart';

// Repositórios e Core
import 'data/park_repository.dart';
import 'data/reviews_repository.dart';
import 'data/repositories/go_park_repository.dart';
import 'data/repositories/go_reviews_repository.dart';
import 'data/repositories/event_repository.dart';

/// ===== CORES/TOKENS =====
const kGreen = Color(0xFF669340);
const kDark  = Color(0xFF32384A);
const kBg    = Color(0xFFF6F7F9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = true;

  await AuthService.instance.init();
  await FavoritesService.instance.init();
  unawaited(RunService.instance.loadActivities());

  // Quando o usuário faz login: sobe pendentes + puxa histórico da nuvem (restore em novo dispositivo)
  AuthService.instance.addListener(() {
    if (AuthService.instance.tokenSync != null) {
      unawaited(RunService.instance.syncPending());
      unawaited(RunService.instance.pullFromCloud());
    }
  });

  final notificationProvider = NotificationProvider();
  await notificationProvider.init();

  // Push notifications (graceful: não quebra se o Firebase ainda não estiver configurado).
  NotificationService.instance
    ..notificationProvider = notificationProvider
    ..onDeepLink = (route) { appRouter.go(route); }
    ..onForegroundToast = (title, body) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        AppToast.show(ctx, title, type: ToastType.info);
      }
    };
  // Remove o token FCM deste dispositivo ao fazer logout.
  AuthService.instance.onBeforeLogout = NotificationService.instance.deleteTokenOnLogout;

  // Não aguardamos: a inicialização é best-effort e não deve travar o boot.
  unawaited(NotificationService.instance.initialize());

  runApp(ParquesApp(notificationProvider: notificationProvider));
}

class ParquesApp extends StatelessWidget {
  const ParquesApp({super.key, required this.notificationProvider});
  final NotificationProvider notificationProvider;

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.poppinsTextTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: FavoritesService.instance),
        ChangeNotifierProvider.value(value: RunService.instance),
        ChangeNotifierProvider.value(value: notificationProvider),
        Provider<ParkRepository>(
          create: (_) => GoParkRepository(),
        ),
        Provider<ReviewsRepository>(
          create: (_) => GoReviewsRepository(),
        ),
        Provider<EventRepository>(
          create: (_) => GoEventRepository(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Parques SLZ',
        debugShowCheckedModeBanner: false,

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],

        // ✅ Usa o GoRouter central
        routerConfig: appRouter,

        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kGreen,
            brightness: Brightness.light,
          ),

          fontFamily: GoogleFonts.poppins().fontFamily,

          textTheme: baseText.copyWith(
            bodyLarge: baseText.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: kDark,
            ),
            bodyMedium: baseText.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: kDark,
            ),
            bodySmall: baseText.bodySmall?.copyWith(
              fontSize: 14,
              height: 1.4,
              color: kDark,
            ),
            titleMedium: baseText.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kGreen,
            ),
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            foregroundColor: kDark,
          ),

          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: kGreen,
            ),
          ),

          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            contentTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
