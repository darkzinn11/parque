// lib/screens/informacoes_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

// Definindo as cores necessárias (kBrandGreen e kDarkGray)
const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);
const kBodyNormalText = Color(0xFF121726); // Usando a cor de texto do Figma

/* ============================================================
 * MODELO DE DADOS
 * ============================================================ */
class _InfoModel {
  final String title;
  final String content;
  final String iconAsset;
  final bool isContentList;

  const _InfoModel({
    required this.title,
    required this.content,
    required this.iconAsset,
    this.isContentList = false,
  });
}

/* ============================================================
 * SCREEN
 * ============================================================ */

class InformacoesScreen extends StatelessWidget {
  const InformacoesScreen({super.key});

  final List<_InfoModel> _sections = const [
    _InfoModel(
      title: 'Funcionamento',
      content: 'Os Parques Ambientais estão abertos todos os dias, das 5h às 22h.',
      iconAsset: 'assets/info/Capa_1.svg', // Assumindo ícone de relógio/calendário
    ),
    _InfoModel(
      title: 'Aproveite',
      content: 'Reúna a família ou os amigos para um piquenique gratuito. Traga sua toalha, sua cesta e o melhor sorriso.',
      iconAsset: 'assets/info/Capa_2.svg', // Assumindo ícone de piquenique/família
    ),
    _InfoModel(
      title: 'O que NÃO pode levar',
      iconAsset: 'assets/info/Capa_3.svg', // Assumindo ícone de proibição
      isContentList: true,
      content:
          'Objetos cortantes, perfurantes, de metal ou vidro (ex.: garrafas, porcelanatos).\n'
          'Bebidas alcoólicas.\n'
          'Fogo de artifício, bombinhas ou cigarros.\n'
          'Qualquer item que possa causar incêndio.',
    ),
    _InfoModel(
      title: 'Quadras Esportivas',
      content: 'As quadras estão disponíveis todos os dias.\n Respeite quem já está jogando e aguarde a sua vez.',
      iconAsset: 'assets/info/Capa_4.svg', // Assumindo ícone de esporte/bola
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kBrandGreen),
          onPressed: () => context.pop(),
        ),
        title: Text('Informações dos Parques',
            style: GoogleFonts.poppins(
                color: kBrandGreen, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._sections.map((section) => _InfoSection(model: section)),

            // Contato/Administração
            Text(
              'Em caso de dúvidas, procure a administração do parque.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kBrandGreen,
              ),
            ),
            
            const SizedBox(height: 40),

            // Importante
            const _ImportantNote(
              iconAsset: 'assets/info/Capa_5.svg', // Assumindo ícone de segurança
              message:
                  'O parque é um espaço familiar e seguro.\n'
                  'Regras simples garantem a diversão de todo mundo.',
              highlight: 'Preserve esse espaço que é de todos!',
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 * COMPONENTES
 * ============================================================ */

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.model});
  final _InfoModel model;

  @override
  Widget build(BuildContext context) {
    // Usamos um Builder para garantir que o path do SVG seja resolvido corretamente
    final iconPath = model.iconAsset;
    final List<String> contentLines = model.isContentList ? model.content.split('\n') : [model.content];

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone
          SizedBox(
            width: 50,
            height: 50,
            child: SvgPicture.asset(iconPath),
          ),
          const SizedBox(height: 8),

          // Título
          Text(
            model.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kBrandGreen,
            ),
          ),
          const SizedBox(height: 8),

          // Conteúdo (Texto ou Lista)
          if (!model.isContentList)
            Text(
              model.content,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kDarkGray,
                height: 1.5,
              ),
            )
          else
            // Lista formatada (para "O que NÃO pode levar")
            ...contentLines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                '• $line', // Usando um bullet point simples
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kDarkGray,
                  height: 1.5,
                ),
              ),
            )),
        ],
      ),
    );
  }
}

class _ImportantNote extends StatelessWidget {
  const _ImportantNote({required this.iconAsset, required this.message, required this.highlight});
  final String iconAsset;
  final String message;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ícone
        SizedBox(
          width: 50,
          height: 50,
          child: SvgPicture.asset(iconAsset),
        ),
        const SizedBox(height: 8),
        
        // Título
        Text(
          'Importante',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kBrandGreen,
          ),
        ),
        const SizedBox(height: 8),

        // Mensagem
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: kDarkGray,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // Destaque
        Text(
          highlight,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700, // Destaque em negrito
            color: kBrandGreen, 
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}