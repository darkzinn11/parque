import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/event_repository.dart';
import '../data/models/app_event.dart';
import '../core/api/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/app_toast.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray   = Color(0xFF32384A);

class EventoDetailScreen extends StatefulWidget {
  const EventoDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<EventoDetailScreen> createState() => _EventoDetailScreenState();
}

class _EventoDetailScreenState extends State<EventoDetailScreen> {
  late Future<AppEvent?> _future;
  bool _meuInteresse = false;
  bool _loadingInteresse = false;
  bool _interesseInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repo = context.read<EventRepository>();
    _future = repo.fetchById(widget.eventId);
  }

  Future<void> _toggleInteresse() async {
    if (AuthService.instance.tokenSync == null) {
      AppToast.show(context, 'Faça login para registrar interesse',
          type: ToastType.warning);
      return;
    }
    final repo = context.read<EventRepository>();
    setState(() => _loadingInteresse = true);
    try {
      await repo.toggleInteresse(widget.eventId, !_meuInteresse);
      setState(() => _meuInteresse = !_meuInteresse);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Erro ao registrar interesse. Tente novamente.',
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loadingInteresse = false);
    }
  }

  String? _toImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    
    if (path.startsWith('http')) {
      if (path.contains('apps.sitw.com.br') && !path.contains('/backend-park/')) {
        return path.replaceFirst('apps.sitw.com.br/', 'apps.sitw.com.br/backend-park/');
      }
      return path;
    }
    
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kBrandGreen),
          onPressed: () => context.pop(),
        ),
        title: Text('Evento',
            style: GoogleFonts.poppins(color: kBrandGreen, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<AppEvent?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrandGreen));
          }
          if (snap.hasError || snap.data == null) {
            return _ErrorBox(message: '${snap.error ?? "Evento não encontrado"}', onRetry: () {
              setState(() => _loadData());
            });
          }

          final ev = snap.data!;
          final capa = _toImageUrl(ev.image);

          // Inicializa o estado de interesse com o valor vindo da API (uma única vez)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_interesseInitialized && !_loadingInteresse && ev.meuInteresse != null) {
              _interesseInitialized = true;
              setState(() => _meuInteresse = ev.meuInteresse!);
            }
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(ev.title,
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700, color: kBrandGreen)),
              const SizedBox(height: 40),

              if (ev.location != null) _InfoLine(icon: Icons.place_outlined, label: 'Local', value: ev.location!),
              if (ev.horario != null) _InfoLine(icon: Icons.schedule_outlined, label: 'Horário', value: ev.horario!),
              if (ev.startDate != null)
                _InfoLine(icon: Icons.event, label: 'Data', value: _formatDateRange(ev.startDate, ev.endDate)),
              const SizedBox(height: 40),

              if (capa != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 87 / 109,
                    child: CachedNetworkImage(
                      imageUrl: capa,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(color: Color(0xFFEFEFEF)),
                      errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFEFEFEF)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (ev.description != null && ev.description!.isNotEmpty) ...[
                Html(
                  data: ev.description!,
                  style: {
                    'body': Style(
                      fontFamily: 'Poppins',
                      fontSize: FontSize(14),
                      lineHeight: const LineHeight(1.55),
                      color: kDarkGray,
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    'p': Style(margin: Margins.only(bottom: 8)),
                    'h2': Style(
                      fontFamily: 'Poppins',
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.w700,
                      color: kDarkGray,
                      margin: Margins.only(top: 12, bottom: 6),
                    ),
                    'h3': Style(
                      fontFamily: 'Poppins',
                      fontSize: FontSize(16),
                      fontWeight: FontWeight.w600,
                      color: kDarkGray,
                      margin: Margins.only(top: 10, bottom: 4),
                    ),
                    'ul': Style(margin: Margins.only(bottom: 8, left: 16)),
                    'ol': Style(margin: Margins.only(bottom: 8, left: 16)),
                    'li': Style(margin: Margins.only(bottom: 4)),
                    'strong': Style(fontWeight: FontWeight.w700),
                    'em': Style(fontStyle: FontStyle.italic),
                    'u': Style(textDecoration: TextDecoration.underline),
                  },
                ),
              ],

              const SizedBox(height: 32),

              _loadingInteresse
                  ? const Center(child: CircularProgressIndicator(color: kBrandGreen))
                  : _meuInteresse
                      ? OutlinedButton.icon(
                          onPressed: _toggleInteresse,
                          icon: const Icon(Icons.notifications_active, color: kBrandGreen),
                          label: Text('Interesse registrado',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, color: kBrandGreen)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kBrandGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        )
                      : FilledButton(
                          onPressed: _toggleInteresse,
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_none_outlined, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Tenho interesse',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateRange(DateTime? a, DateTime? b) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    if (a != null && b != null) return '${fmt(a)} à ${fmt(b)}';
    if (a != null) return fmt(a);
    if (b != null) return fmt(b);
    return '';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kBrandGreen),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: kDarkGray),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}