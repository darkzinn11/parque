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
  int _selectedSlotIndex = -1;

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadSpaceAndSlots();
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
      _selectedSlotIndex = -1;
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
    if (_selectedSlotIndex == -1) {
      AppToast.show(context, 'Por favor, selecione um horário.', type: ToastType.error);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_dates[_selectedDateIndex]);
    final slot = _slots[_selectedSlotIndex];
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
          icon: const Icon(Icons.arrow_back_ios_new, color: _green, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Escolha data e horário',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 18,
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
                      // Carrossel de datas semanais
                      SizedBox(
                        height: 76,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _dates.length,
                          itemBuilder: (context, index) {
                            final date = _dates[index];
                            final isSelected = index == _selectedDateIndex;
                            final dayLabel = _getDayLabel(date);

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDateIndex = index;
                                  });
                                  _loadSlots();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 62,
                                  decoration: BoxDecoration(
                                    color: isSelected ? _green : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? _green : const Color(0xFFECECEC),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dayLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : _lightGray,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date.day.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : _dark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Horários disponíveis',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Grid de horários
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _isLoadingSlots
                            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _green)))
                            : _slots.isEmpty
                                ? _buildEmptySlotsState()
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.8,
                                    ),
                                    itemCount: _slots.length,
                                    itemBuilder: (context, index) {
                                      final isSelected = index == _selectedSlotIndex;
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedSlotIndex = index;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected ? _green : Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? _green : const Color(0xFFECECEC),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _slots[index],
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? Colors.white : _dark,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                // Botão Continuar → formulário de participantes
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continuar',
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

  String _getDayLabel(DateTime date) {
    final weekday = date.weekday;
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
    }
    return '';
  }
}
