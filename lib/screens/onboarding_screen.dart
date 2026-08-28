import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_router.dart';

const String kOnboardingSeenKey = 'onboarding_seen';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Descubra os Parques",
      "subtitle":
          "Conheça os parques de São Luís e encontre o espaço ideal para você.",
      "img": "assets/images/onboarding1.webp",
    },
    {
      "title": "Atividades e Eventos",
      "subtitle":
          "Fique por dentro da agenda de eventos e agende sua participação.",
      "img": "assets/images/onboarding2.webp",
    },
    {
      "title": "Reserve Seu Espaço",
      "subtitle":
          "Agende quadras, áreas de lazer ou espaços para o seu grupo.",
      "img": "assets/images/onboarding3.webp",
    },
    {
      "title": "Vem pro Parque!",
      "subtitle":
          "Agende quadras, áreas de lazer\nou espaços para o seu grupo.",
      "img": "assets/images/onboarding4.webp",
    },
  ];

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pré-carrega as ilustrações uma única vez para o swipe ficar fluido.
    if (!_precached) {
      for (final page in _pages) {
        precacheImage(AssetImage(page['img']!), context);
      }
      _precached = true;
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage == _pages.length - 1) {
      // ✅ Última página: marca que o onboarding foi concluído
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingSeenKey, true);

      if (!mounted) return;
      context.go(AppRoutes.home);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildImage(String path, double maxWidth, double maxHeight) {
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          /// Fundo
          Positioned.fill(
            child: Image.asset(
              "assets/images/splash_bg.png",
              fit: BoxFit.cover,
            ),
          ),

          /// Conteúdo
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                /// Páginas
                Expanded(
                  flex: 12,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final page = _pages[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// Título
                            Text(
                              page["title"]!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF32384A),
                              ),
                            ),

                            const SizedBox(height: 12),

                            /// Subtítulo
                            if (page["subtitle"]!.isNotEmpty)
                              Text(
                                page["subtitle"]!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                  color: const Color(0xFF32384A),
                                ),
                              ),

                            const SizedBox(height: 40),

                            /// Ilustração
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: size.height * 0.35,
                                ),
                                child: _buildImage(
                                  page["img"]!,
                                  size.width - 64,
                                  size.height * 0.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(),

                /// Indicadores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            isActive ? const Color(0xFF607C3C) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                /// Botão
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF607C3C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black26,
                      ),
                      child: _currentPage == _pages.length - 1
                          ? Text(
                              "Começar",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Próximo",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
