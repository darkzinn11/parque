import 'package:flutter/material.dart';
import '../../services/spaces_service.dart';
import '../../services/reservations_service.dart';
import '../../widgets/login_required.dart';

const _green = Color(0xFF669340);
const _chipBg = Color(0xFFEFF6E9);
const _chipOff = Color(0xFFF1F1F1);

class ReservationCreateScreen extends StatefulWidget {
  final String spaceId;
  const ReservationCreateScreen({super.key, required this.spaceId});

  @override
  State<ReservationCreateScreen> createState() => _ReservationCreateScreenState();
}

class _ReservationCreateScreenState extends State<ReservationCreateScreen> {
  final _spaces = SpacesService();
  final _reservations = ReservationsService();

  SpaceItem? _space;
  bool _loading = true;

  DateTime _date = DateTime.now();
  String? _selectedSlot; // HH:mm
  Set<String> _taken = {}; // HH:mm ocupados

  final _note = TextEditingController();

  final List<String> _morning = const ['09:00','10:00','11:00','12:00'];
  final List<String> _afternoon = const ['13:00','14:00','15:00','16:00'];
  final List<String> _night = const ['19:00','20:00','21:00'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await _spaces.getById(widget.spaceId);
    if (!mounted) return;
    setState(() { _space = sp; });
    await _loadAvailability();
    if (!mounted) return;
    setState(() { _loading = false; });
  }

  Future<void> _loadAvailability() async {
    _taken = await _reservations.reservedSlots(spaceId: widget.spaceId, date: _date);
    // se o slot selecionado ficou indisponível ao mudar a data, limpa
    if (_selectedSlot != null && _taken.contains(_selectedSlot)) {
      _selectedSlot = null;
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _date,
    );
    if (d != null) {
      setState(() => _date = d);
      await _loadAvailability();
    }
  }

  TimeOfDay _parseHHmm(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  TimeOfDay _plus1h(TimeOfDay t) {
    var h = t.hour + 1;
    return TimeOfDay(hour: h, minute: t.minute);
  }

  Future<void> _submit() async {
    final okLogin = await requireLogin(context, featureName: 'reservas');
    if (!okLogin) return;

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um horário.')));
      return;
    }

    final start = _parseHHmm(_selectedSlot!);
    final end = _plus1h(start);

    final ok = await _reservations.create(
      spaceId: widget.spaceId,
      date: _date,
      start: start,
      end: end,
      note: _note.text,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva enviada!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível reservar.')));
    }
  }

  Widget _slotChip(String hhmm) {
    final disabled = _taken.contains(hhmm);
    final selected = _selectedSlot == hhmm && !disabled;
    return InkWell(
      onTap: disabled ? null : () => setState(() => _selectedSlot = hhmm),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? _chipOff : (selected ? _chipBg : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: disabled ? Colors.grey.shade300 : _green.withOpacity(.4)),
        ),
        child: Text(
          hhmm,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: disabled ? Colors.grey : (selected ? _green : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _slotSection(String title, List<String> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: slots.map(_slotChip).toList(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final image = _space?.coverUrl;
    final title = _space?.title ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // Header image
          if (image != null)
            Image.network(image, height: 220, width: double.infinity, fit: BoxFit.cover),

          // Conteúdo "card" branco
          Positioned.fill(
            top: 180,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: _green),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Selecione data e horário para criar o agendamento',
                      style: TextStyle(color: Colors.grey.shade600)),

                  const SizedBox(height: 16),
                  Text('Data', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: _green),
                          const SizedBox(width: 8),
                          Text(
                            '${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.keyboard_arrow_down, color: _green),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text('Horários', style: TextStyle(fontWeight: FontWeight.w800)),

                  const SizedBox(height: 8),
                  _slotSection('Manhã', _morning),
                  _slotSection('Tarde', _afternoon),
                  _slotSection('Noite', _night),

                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    minLines: 2, maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Agendar agora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
