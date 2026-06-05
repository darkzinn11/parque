// lib/screens/reservations/booking_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _lightGray = Color(0xFF8F959E);

class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({super.key, required this.spaceId});
  final int spaceId;

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final _repository = SpaceRepository();
  bool _isLoadingSpace = true;
  bool _isLoadingSlots = false;

  Space? _space;
  List<DateTime> _dates = [];
  int _selectedDateIndex = 0;

  List<String> _slots = [];
  String? _selectedSlotValue;

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadSpaceAndSlots();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _generateDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Regra de negócio: só é possível reservar dentro da semana atual (dom–sáb).
    // weekday: Mon=1..Sun=7 → wd: Dom=0, Seg=1, ..., Sáb=6.
    final wd = today.weekday % 7;
    final daysUntilSaturday = 6 - wd;
    _dates = List.generate(
      daysUntilSaturday + 1,
      (index) => today.add(Duration(days: index)),
    );
  }

  Future<void> _loadSpaceAndSlots() async {
    setState(() => _isLoadingSpace = true);
    final detail = await _repository.fetchSpaceById(widget.spaceId);
    if (mounted) {
      setState(() {
        _space = detail;
        _isLoadingSpace = false;
      });
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    if (_space == null) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedSlotValue = null;
    });

    final date = _dates[_selectedDateIndex];
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    var slots = await _repository.fetchAvailability(widget.spaceId, dateStr);

    // Se for hoje, remove slots cujo horário de início já passou.
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      final nowMinutes = now.hour * 60 + now.minute;
      slots = slots.where((slot) {
        final parts = slot.split(' - ');
        if (parts.isEmpty) return false;
        final timeParts = parts[0].split(':');
        if (timeParts.length < 2) return false;
        final slotMinutes = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
        return slotMinutes > nowMinutes;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _slots = slots;
        _isLoadingSlots = false;
      });
    }
  }

  void _continue() {
    if (_selectedSlotValue == null) {
      AppToast.show(context, 'Por favor, selecione um horário.', type: ToastType.error);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_dates[_selectedDateIndex]);
    final slot = _selectedSlotValue!;
    final times = slot.split(' - ');
    final startTime = times[0];
    final endTime = times.length > 1 ? times[1] : '';

    context.push(
      '/tabs/home/reservas/espaco/${widget.spaceId}/formulario',
      extra: {
        'spaceId': widget.spaceId,
        'spaceName': _space?.name ?? 'Espaço',
        'capacityMax': _space?.maxCapacity ?? 0,
        'termsOfUse': _space?.rule?.termsOfUse ?? '',
        'data': dateStr,
        'horaInicio': startTime,
        'horaFim': endTime,
        'numParticipants': 1, // participantes adicionados na próxima tela
      },
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
          'Seleção de Data e Horário',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingSpace
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      // Espaço Título
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _space?.name ?? '',
                          style: GoogleFonts.poppins(
                            color: _green,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtítulo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Selecione data, horário para criar o agendamento',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF32384A),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Campo Data (Dropdown/DatePicker)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDFDFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<int>(
                                value: _selectedDateIndex,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _green, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _green, width: 2),
                                  ),
                                ),
                                icon: const Icon(Icons.keyboard_arrow_down, color: _dark),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                onChanged: (int? newValue) {
                                  if (newValue != null && mounted) {
                                    setState(() {
                                      _selectedDateIndex = newValue;
                                    });
                                    _loadSlots();
                                  }
                                },
                                items: List.generate(_dates.length, (index) {
                                  final date = _dates[index];
                                  final formattedDate = DateFormat('dd/MM/yyyy').format(date);
                                  return DropdownMenuItem<int>(
                                    value: index,
                                    child: Text(
                                      formattedDate,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _dark,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Horários Disponíveis
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Horários disponíveis',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_isLoadingSlots)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: _green),
                          ),
                        )
                      else if (_slots.isEmpty)
                        _buildEmptySlotsState()
                      else ...[
                        _buildPeriodSection('Manhã', _getSlotsByPeriod('manha')),
                        _buildPeriodSection('Tarde', _getSlotsByPeriod('tarde')),
                        _buildPeriodSection('Noite', _getSlotsByPeriod('noite')),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                // Botão Agendar agora
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Agendar agora',
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

  Widget _buildEmptySlotsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.event_busy, color: _lightGray, size: 36),
            const SizedBox(height: 12),
            Text(
              'Espaço fechado ou indisponível',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSection(String title, List<String> slots) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slots.map((slot) {
              final isAvailable = _slots.contains(slot);
              final isSelected = _selectedSlotValue == slot;
              final startHour = slot.split(' - ')[0];

              return InkWell(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _selectedSlotValue = slot;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: (MediaQuery.of(context).size.width - 48 - 36) / 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? _green : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? _green
                          : isAvailable
                              ? _green
                              : const Color(0xFFECECEC),
                      width: isAvailable && !isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    startHour,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isAvailable
                              ? _green
                              : const Color(0xFFC4C4C4),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _generateAllSlots() {
    if (_space == null) return [];

    int startHour = 8;
    int endHour = 18;
    if (_space!.rule != null) {
      final openParts = _space!.rule!.openingTime.split(':');
      final closeParts = _space!.rule!.closingTime.split(':');
      if (openParts.isNotEmpty) startHour = int.tryParse(openParts[0]) ?? 8;
      if (closeParts.isNotEmpty) endHour = int.tryParse(closeParts[0]) ?? 18;
    }

    final List<String> list = [];
    for (int hour = startHour; hour + 2 <= endHour; hour += 2) {
      final startStr = '${hour.toString().padLeft(2, '0')}:00';
      final endStr = '${(hour + 2).toString().padLeft(2, '0')}:00';
      list.add('$startStr - $endStr');
    }
    return list;
  }

  List<String> _getSlotsByPeriod(String period) {
    final all = _generateAllSlots();
    return all.where((slot) {
      final startHourStr = slot.split(' - ')[0].split(':')[0];
      final hour = int.tryParse(startHourStr) ?? 0;
      if (period == 'manha') {
        return hour < 12;
      } else if (period == 'tarde') {
        return hour >= 12 && hour < 18;
      } else {
        return hour >= 18;
      }
    }).toList();
  }


}
