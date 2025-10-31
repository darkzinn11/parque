import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Serviços
import 'services/auth_service.dart';
import 'services/favorites_service.dart';

/// ===== CORES/TOKENS =====
const kGreen = Color(0xFF669340);
const kDark  = Color(0xFF32384A);
const kBg    = Color(0xFFF6F7F9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins offline/determinístico (não baixa em runtime)
  GoogleFonts.config.allowRuntimeFetching = false;

  // 1) Autenticação (recupera token + usuário, se houver)
  await AuthService.instance.init();

  // 2) Favoritos (carrega do usuário logado, se houver)
  await FavoritesService.instance.init();

  runApp(const ParquesApp());
}

class ParquesApp extends StatelessWidget {
  const ParquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.poppinsTextTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: FavoritesService.instance),
      ],
      child: MaterialApp.router(
        title: 'Parques SLZ',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kGreen,
            brightness: Brightness.light,
          ),

          // Fonte global = Poppins
          fontFamily: GoogleFonts.poppins().fontFamily,

          // Tipografia base (Body 16/24; títulos conforme Figma)
          textTheme: baseText.copyWith(
            bodyLarge:  baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: kDark),
            bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: kDark),
            bodySmall:  baseText.bodySmall?.copyWith(fontSize: 14, height: 1.4, color: kDark),
            titleMedium: baseText.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: kGreen),
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
            contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
