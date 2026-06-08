import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../data/repositories/event_repository.dart';
import '../data/models/app_event.dart';

const kBrandGreen = Color(0xFF669340);
const kDarkGray   = Color(0xFF32384A);
const kFigmaSearchFill = Color(0xFFFFFFE9);
const kFigmaSearchHint = Color(0xFFBCC1A6);
const kBodyNormalText = Color(0xFF121726);

class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key});
  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

class _EventosListScreenState extends State<EventosListScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<AppEvent> _all = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    
    try {
      final repo = context.read<EventRepository>();
      final items = await repo.fetchAll();
      
      if (!mounted) return;
      setState(() { 
        _all = items; 
        _loading = false; 
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { 
        _error = 'Falha ao carregar eventos: $e'; 
        _loading = false; 
      });
    }
  }

  List<AppEvent> get _filtered {
    if (_q.trim().isEmpty) return _all;
    final s = _q.toLowerCase();
    return _all.where((e) => e.title.toLowerCase().contains(s)).toList();
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
        title: Text('Eventos', style: GoogleFonts.poppins(
          color: kBrandGreen, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrandGreen))
          : _error != null
              ? _ErrorBox(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: kBrandGreen,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Text('Seus parques e atividades salvos em um só lugar.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: kBodyNormalText,
                            fontWeight: FontWeight.w400,
                            height: 20 / 14,
                          )),
                      const SizedBox(height: 16),
                      _SearchBar(
                        controller: _searchCtrl,
                        hint: 'Buscar por evento',
                        onSubmitted: (v) => setState(() => _q = v.trim()),
                      ),
                      const SizedBox(height: 40),
                      if (_filtered.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text('Nenhum evento encontrado.',
                                style: GoogleFonts.poppins(color: kDarkGray.withValues(alpha: .7))),
                          ),
                        )
                      else
                        ..._filtered.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 20), 
                              child: _EventoCard(
                                data: e,
                                onTap: () => context.push(AppRoutes.eventoDetail(e.id)),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}

// ====== UI ======
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.hint, this.onSubmitted});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBrandGreen, width: 2),
    );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: GoogleFonts.poppins(fontSize: 14, color: kDarkGray),
      decoration: InputDecoration(
        filled: true,
        fillColor: kFigmaSearchFill,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: kFigmaSearchHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        enabledBorder: border,
        focusedBorder: border,
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 12.0),
          child: Icon(Icons.search, color: kDarkGray),
        ),
      ),
    );
  }
}

class _EventoCard extends StatelessWidget {
  const _EventoCard({required this.data, this.onTap});
  final AppEvent data;
  final VoidCallback? onTap;

  String _formatDateRange(DateTime? a, DateTime? b) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    if (a != null && b != null) return '${fmt(a)} à ${fmt(b)}';
    if (a != null) return fmt(a);
    if (b != null) return fmt(b);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDateRange(data.startDate, data.endDate);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16/9,
              child: data.image == null
                  ? Container(color: const Color(0xFFEFEFEF))
                  : Image.network(
                      data.image!, 
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFEFEF)),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(data.title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: kBrandGreen)),
          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(dateText, style: GoogleFonts.poppins(fontSize: 13, color: kDarkGray.withValues(alpha: .8))),
          ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 8),
          Text('Falha ao carregar eventos', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrandGreen),
            onPressed: onRetry,
            child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}