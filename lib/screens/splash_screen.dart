import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave do Onboarding
const String kOnboardingSeenKey = 'onboarding_seen';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  /// =====================================================
  /// 🔥 Fluxo otimizado:
  /// 1. Verifica onboarding
  /// 2. Verifica login
  /// 3. Carrega usuário
  /// 4. Carrega favoritos
  /// 5. Redireciona imediatamente
  /// =====================================================
  Future<void> _start() async {
    // Aguarda 100ms só para permitir renderizar a splash
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(kOnboardingSeenKey) ?? false;

    final isLogged = await AuthService.instance.isLogged();

    if (isLogged) {
      // Carrega dados do usuário sem travar UI
      await AuthService.instance.refreshUser();

      // Carrega favoritos do usuário
      await FavoritesService.instance.init();
    }

    if (!mounted) return;

    // --- REDIRECIONAMENTO ---
    if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
      return;
    }

    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Fundo
          const Image(
            image: AssetImage('assets/images/splash_bg.png'),
            fit: BoxFit.cover,
          ),

          /// Logo central
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: SvgPicture.asset('assets/images/logo.svg'),
            ),
          ),
        ],
      ),
    );
  }
}
