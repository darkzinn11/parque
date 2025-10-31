import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/spaces_service.dart';
import '../../routes/app_router.dart';

const _green   = Color(0xFF669340);
const _chipBg  = Color(0xFFEFF6E9);
// >>> cor de fundo igual ao Figma (off-white / cinza bem claro)
const _pageBg  = Color(0xFFF7F7F7);

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _svc = SpacesService();
  List<SpaceItem> _all = [];
  List<String> _cats = ['Todos'];
  String _selected = 'Todos';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await _svc.list();
    final cats = <String>{'Todos'};
    for (final s in items) {
      if (s.type.isNotEmpty) cats.add(s.type);
    }
    if (!mounted) return;
    setState(() {
      _all = items;
      _cats = cats.toList()..sort((a,b){
        if (a=='Todos') return -1;
        if (b=='Todos') return 1;
        return a.compareTo(b);
      });
      _loading = false;
    });
  }

  List<SpaceItem> get _filtered =>
      _selected == 'Todos' ? _all : _all.where((e) => e.type == _selected).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // >>> aplica o fundo da tela (não branco puro)
      backgroundColor: _pageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
          color: _green,
        ),
        backgroundColor: Colors.white,     // AppBar branco
        surfaceTintColor: Colors.white,    // evita “tinta” do Material 3
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text(
            'Reserve seu espaço',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _green),
          ),
          const SizedBox(height: 8),
          Text(
            'Garanta seu espaço no parque! Agende quadras, salas e áreas para aproveitar com seus amigos, familiares ou grupos.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 12),

          // Chips em Wrap (várias linhas)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cats.map((c) {
              final sel = c == _selected;
              return InkWell(
                onTap: () => setState(() => _selected = c),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _chipBg : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _green.withOpacity(.4)),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sel ? _green : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Grid de cards
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .86),
            itemBuilder: (_, i) {
              final s = _filtered[i];
              return InkWell(
                onTap: () => context.push(AppRoutes.homeReservaNova(s.id)),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // card branco destacando no fundo cinza
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.coverUrl != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            s.coverUrl!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.parkName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
