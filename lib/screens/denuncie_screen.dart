import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_toast.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray = Color(0xFF32384A);
const kSubtitleColor = Color(0xFF6B7280);

class DenuncieScreen extends StatefulWidget {
  const DenuncieScreen({super.key});

  @override
  State<DenuncieScreen> createState() => _DenuncieScreenState();
}

class _DenuncieScreenState extends State<DenuncieScreen> {
  // Personal Info Controllers
  final _emailController = TextEditingController();
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();

  // Optional Address Controller
  bool _informarEndereco = false;
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();

  // Report Location Controllers
  final _cidadeController = TextEditingController();
  final _enderecoDenunciaController = TextEditingController();
  final _pontoReferenciaController = TextEditingController();

  // Report Detail Controllers
  String _categoriaSelecionada = 'Infraestrutura';
  final _descricaoController = TextEditingController();

  // Termos e confirmação
  bool _concordoTermos = false;
  bool _informacoesVerdadeiras = false;

  bool _enviando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _celularController.dispose();
    _cepController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _enderecoDenunciaController.dispose();
    _pontoReferenciaController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String hintText,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: kDarkGray,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
          prefixIcon: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    icon,
                    color: kBrandGreen.withValues(alpha: 0.8),
                    size: 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFFAFBF0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF669340), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF669340), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF669340), width: 2.0),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(
          icon,
          color: kBrandGreen,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kDarkGray,
          ),
        ),
      ],
    );
  }

  Future<void> _submitDenuncia() async {
    // Basic Form Validation
    if (_emailController.text.trim().isEmpty ||
        _nomeController.text.trim().isEmpty ||
        _celularController.text.trim().isEmpty) {
      AppToast.show(context, 'Por favor, preencha os seus dados pessoais.', type: ToastType.warning);
      return;
    }

    if (_cidadeController.text.trim().isEmpty ||
        _enderecoDenunciaController.text.trim().isEmpty) {
      AppToast.show(context, 'Por favor, informe a cidade e o endereço do local da denúncia.', type: ToastType.warning);
      return;
    }

    if (_descricaoController.text.trim().isEmpty) {
      AppToast.show(context, 'Por favor, descreva detalhadamente o problema.', type: ToastType.warning);
      return;
    }

    if (!_concordoTermos || !_informacoesVerdadeiras) {
      AppToast.show(context, 'Você precisa aceitar os termos e confirmar a veracidade das informações.', type: ToastType.warning);
      return;
    }

    setState(() => _enviando = true);

    // Simulate API network request
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() => _enviando = false);

    // Show beautiful Figma success dialog
    _mostrarDialogoSucessoDenuncia(_categoriaSelecionada);
  }

  void _mostrarDialogoSucessoDenuncia(String categoria) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Obrigado pelo seu relato!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kDarkGray,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sua denúncia de $categoria foi registrada com sucesso e nossa equipe já foi notificada para tomar as devidas providências.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kDarkGray.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Closes Success Dialog
                      context.pop(); // Returns to Home Screen
                    },
                    child: Text(
                      'Entendido',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row with back arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: kBrandGreen,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Faça sua denúncia',
                      style: GoogleFonts.poppins(
                        color: kBrandGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              // Centered Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Informe os dados abaixo para registrar sua denúncia.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: kSubtitleColor,
                    height: 1.428,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              // Main Form Cards and Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Dados Pessoais Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            icon: Icons.person_outline,
                            title: 'Dados pessoais',
                          ),
                          const SizedBox(height: 20),
                          _buildField(
                            hintText: 'E-mail',
                            controller: _emailController,
                            icon: Icons.mail_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildField(
                            hintText: 'Nome completo',
                            controller: _nomeController,
                            icon: Icons.person_outline,
                          ),
                          _buildField(
                            hintText: 'Celular',
                            controller: _celularController,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),

                    // 2. Informar Meu Endereço Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Informar meu endereço',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kDarkGray,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Opcional. Selecione para informar.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _informarEndereco,
                                activeColor: Colors.white,
                                activeTrackColor: kBrandGreen,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: const Color(0xFFE5E7EB),
                                onChanged: (val) {
                                  setState(() {
                                    _informarEndereco = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_informarEndereco) ...[
                            const SizedBox(height: 20),
                            _buildField(
                              hintText: 'CEP',
                              controller: _cepController,
                              keyboardType: TextInputType.number,
                            ),
                            _buildField(
                              hintText: 'Rua',
                              controller: _ruaController,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 35,
                                  child: _buildField(
                                    hintText: 'Número',
                                    controller: _numeroController,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 65,
                                  child: _buildField(
                                    hintText: 'Complemento',
                                    controller: _complementoController,
                                  ),
                                ),
                              ],
                            ),
                            _buildField(
                              hintText: 'Bairro',
                              controller: _bairroController,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 3. Local da Denúncia Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            icon: Icons.location_on_outlined,
                            title: 'Local da denúncia',
                          ),
                          const SizedBox(height: 20),
                          _buildField(
                            hintText: 'Cidade da denúncia',
                            controller: _cidadeController,
                          ),
                          _buildField(
                            hintText: 'Endereço da denúncia',
                            controller: _enderecoDenunciaController,
                          ),
                          _buildField(
                            hintText: 'Ponto de referência',
                            controller: _pontoReferenciaController,
                          ),
                        ],
                      ),
                    ),

                    // 4. Detalhes e anexos Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            icon: Icons.assignment_outlined,
                            title: 'Detalhes e anexos',
                          ),
                          const SizedBox(height: 20),
                          _buildField(
                            hintText: 'Descreva a denúncia aqui...',
                            controller: _descricaoController,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          CustomPaint(
                            painter: DashedRectPainter(),
                            child: InkWell(
                              onTap: () {
                                // Ação de simular anexar foto
                                AppToast.show(context, 'Simulando upload de foto...', type: ToastType.info);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 110,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: kBrandGreen,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Anexar fotos',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: kBrandGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tamanho máximo por arquivo: 25 MB.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. Confirmação Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Confirmação',
                          ),
                          const SizedBox(height: 20),
                          _buildCheckboxRow(
                            text: 'Concordo com os termos e condições.',
                            value: _concordoTermos,
                            onChanged: (val) {
                              setState(() {
                                _concordoTermos = val;
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          _buildCheckboxRow(
                            text: 'Afirmo que as informações aqui prestadas são verdadeiras.',
                            value: _informacoesVerdadeiras,
                            onChanged: (val) {
                              setState(() {
                                _informacoesVerdadeiras = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _enviando ? null : _submitDenuncia,
                        child: _enviando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Enviar ocorrência',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kBrandGreen,
                  width: 2.0,
                ),
                color: value ? kBrandGreen : Colors.transparent,
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kDarkGray,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedRectPainter({
    this.color = kBrandGreen,
    this.strokeWidth = 1.2,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = _buildDashedPath(path, dashLength, gap);
    canvas.drawPath(dashPath, paint);
  }

  Path _buildDashedPath(Path source, double dashLength, double gap) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashLength : gap;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
