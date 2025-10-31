import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
// import 'package:lottie/lottie.dart'; // <<< 1. REMOVIDO
import 'package:flutter_svg/flutter_svg.dart'; // <<< 2. ADICIONADO
import '../routes/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // <<< 3. LISTA ATUALIZADA para usar SVGs >>>
  final List<Map<String, String>> _pages = [
    {
      "title": "Descubra os Parques",
      "subtitle": "Conheça os parques de São Luís e encontre o espaço ideal para você.",
      "svg": "assets/images/onboarding1.svg", // Assumindo que seus SVGs estão em assets/images/
    },
    {
      "title": "Atividades e Eventos",
      "subtitle": "Fique por dentro da agenda de eventos e agende sua participação.",
      "svg": "assets/images/onboarding2.svg",
    },
    {
      "title": "Reserve Seu Espaço",
      "subtitle": "Agende quadras, áreas de lazer ou espaços para o seu grupo.",
      "svg": "assets/images/onboarding3.svg",
    },
    {
      "title": "Tudo pronto!",
      "subtitle": "Agora, reúna sua galera\ne Vem Pro Parque!",
      "svg": "assets/images/onboarding4.svg",
    },
  ];

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      context.go(AppRoutes.home);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }
  
  // <<< 4. FUNÇÃO TROCADA de Lottie para SVG >>>
  Widget _buildSvg(String path, {double w = 342, double h = 238}) {
    return SizedBox(
      width: w,
      height: h,
      child: SvgPicture.asset(
        path,
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

          /// Páginas
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final page = _pages[index];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 200),

                  /// Título
                  Text(
                    page["title"]!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF32384A),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Subtítulo
                  if (page["subtitle"]!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        page["subtitle"]!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF32384A),
                        ),
                      ),
                    ),

                  const SizedBox(height: 48),

                  // <<< 5. CHAMADA DA FUNÇÃO ATUALIZADA >>>
                  /// Imagem SVG
                  _buildSvg(
                    page["svg"]!,
                    w: index == _pages.length - 1 ? 342 : 342,
                    h: index == _pages.length - 1 ? 320 : 238,
                  ),
                ],
              );
            },
          ),

          /// Indicadores + Botão
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Column(
              children: [
                /// Indicador
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? const Color(0xFF607C3C)
                            : Colors.white,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                /// Botão
                SizedBox(
                  width: 327,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Próximo",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.white),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}