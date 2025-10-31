import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_router.dart';
import 'home_screen.dart'; // se quiser usar no preview de IDE, mas não é necessário pra navegação

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simula inicialização e então navega via go_router
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      context.go(AppRoutes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/splash_bg.png'),
            fit: BoxFit.cover,
          ),
        ],
      ),
    );
  }
}
