// lib/screens/reservations/space_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../core/api/api_config.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);

class SpaceDetailScreen extends StatefulWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});
  final int spaceId;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  final _repository = SpaceRepository();
  bool _isLoading = true;
  Space? _space;

  int _selectedImageIndex = 0;
  final List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _loadSpaceDetails();
  }

  Future<void> _loadSpaceDetails() async {
    final detail = await _repository.fetchSpaceById(widget.spaceId);
    if (mounted) {
      setState(() {
        _space = detail;
        _isLoading = false;

        // Collect available images
        if (detail != null) {
          if (detail.imageURL != null && detail.imageURL!.isNotEmpty) {
            _images.add(detail.imageURL!);
          }
          if (detail.imageUrl2 != null && detail.imageUrl2!.isNotEmpty) {
            _images.add(detail.imageUrl2!);
          }
          if (detail.imageUrl3 != null && detail.imageUrl3!.isNotEmpty) {
            _images.add(detail.imageUrl3!);
          }
          if (detail.imageUrl4 != null && detail.imageUrl4!.isNotEmpty) {
            _images.add(detail.imageUrl4!);
          }
        }
      });
    }
  }

  String? _toImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  void _showFullImage(String imgUrl) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Informações do Espaço',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _space == null
              ? _buildErrorState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 40),
                        children: [
                          // Título do espaço
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _space!.name,
                              style: GoogleFonts.poppins(
                                color: _green,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Imagem Principal
                          if (_images.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: GestureDetector(
                                onTap: () => _showFullImage(_toImageUrl(_images[_selectedImageIndex])!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 10,
                                    child: CachedNetworkImage(
                                      imageUrl: _toImageUrl(_images[_selectedImageIndex])!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[100]),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Miniaturas de Fotos
                            if (_images.length > 1)
                              SizedBox(
                                height: 86, // slightly larger to prevent vertical clipping of border
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  itemCount: _images.length,
                                  itemBuilder: (context, index) {
                                    final isSelected = index == _selectedImageIndex;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 4),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImageIndex = index;
                                          });
                                        },
                                        child: Container(
                                          width: 120,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? _green : Colors.transparent,
                                              width: 2.0,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: CachedNetworkImage(
                                              imageUrl: _toImageUrl(_images[index])!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],

                          // Descrição
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _space!.description ?? 'Sem descrição disponível.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                color: _dark,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Regras / Informações de funcionamento
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDetailRow(
                                  icon: Icons.location_on_outlined,
                                  text: _space!.address ?? 'Localização não cadastrada.',
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  icon: Icons.access_time,
                                  text: _space!.rule != null
                                      ? 'Aberto das ${_space!.rule!.openingTime} às ${_space!.rule!.closingTime}'
                                      : 'Aberto das 08:00 às 18:00',
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  text: _space!.rule != null
                                      ? _translateWorkingDays(_space!.rule!.workingDays)
                                      : 'Segunda à sexta',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botão Inferior Agendar — só exibe quando o espaço aceita reservas
                    if (_space!.rule != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                        child: FilledButton(
                          onPressed: () => context.push('/tabs/home/reservas/espaco/${_space!.id}/agendar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Agendar um horário',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _green, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _dark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _translateWorkingDays(String days) {
    final lower = days.toLowerCase();
    if (lower == 'seg-sex') return 'Segunda à sexta';
    if (lower == 'seg-dom') return 'Todos os dias';
    if (lower == 'sab-dom' || lower == 'fim-de-semana') return 'Finais de semana';
    return days;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar detalhes',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }
}
