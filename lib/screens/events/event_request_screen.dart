// lib/screens/events/event_request_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../widgets/app_toast.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);
const _gray = Color(0xFF8F959E);
const _disabled = Color(0xFFD8D8D8);
const _cardBg = Color(0xFFF9FAE8);

const _minDaysAhead = 15;
const _maxDaysAhead = 180;

// 1h increments, 07:00 – 22:00
final _timeSlots = List.generate(16, (i) {
  final h = 7 + i;
  return '${h.toString().padLeft(2, '0')}:00';
});

int _toMin(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

class EventRequestScreen extends StatefulWidget {
  const EventRequestScreen({super.key, required this.parkId});
  final int parkId;

  @override
  State<EventRequestScreen> createState() => _EventRequestScreenState();
}

class _EventRequestScreenState extends State<EventRequestScreen> {
  final _repo = SpaceRepository();

  List<Space> _spaces = [];
  final Set<int> _selectedSpaceIds = {};
  DateTime? _selectedDate;
  late DateTime _displayMonth;
  String? _horaInicio;
  String? _horaFim;
  bool _isLoadingSpaces = true;

  late final DateTime _minDate;
  late final DateTime _maxDate;

  bool _spaceError = false;
  bool _dateError = false;
  bool _horaInicioError = false;
  bool _horaFimError = false;
  final _scrollController = ScrollController();
  final _spaceSectionKey = GlobalKey();
  final _dateSectionKey = GlobalKey();
  final _horaInicioSectionKey = GlobalKey();
  final _horaFimSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minDate = DateTime(now.year, now.month, now.day + _minDaysAhead);
    _maxDate = DateTime(now.year, now.month, now.day + _maxDaysAhead);
    _displayMonth = DateTime(_minDate.year, _minDate.month);
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    setState(() => _isLoadingSpaces = true);
    final spaces = await _repo.fetchSpaces(parkId: widget.parkId);
    if (mounted) {
      setState(() {
        _spaces = spaces;
        _isLoadingSpaces = false;
      });
    }
  }

  void _prevMonth() {
    final prev = DateTime(_displayMonth.year, _displayMonth.month - 1);
    final minMonth = DateTime(_minDate.year, _minDate.month);
    if (!prev.isBefore(minMonth)) setState(() => _displayMonth = prev);
  }

  void _nextMonth() {
    final next = DateTime(_displayMonth.year, _displayMonth.month + 1);
    if (!next.isAfter(DateTime(_maxDate.year, _maxDate.month))) {
      setState(() => _displayMonth = next);
    }
  }

  List<String> get _endOptions {
    if (_horaInicio == null) return _timeSlots;
    final min = _toMin(_horaInicio!);
    return _timeSlots.where((t) => _toMin(t) > min).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _continue() {
    final spaceErr = _selectedSpaceIds.isEmpty;
    final dateErr = _selectedDate == null;
    final horaInicioErr = _horaInicio == null;
    final horaFimErr = _horaInicio != null && _horaFim == null;

    if (spaceErr || dateErr || horaInicioErr || horaFimErr) {
      setState(() {
        _spaceError = spaceErr;
        _dateError = dateErr;
        _horaInicioError = horaInicioErr;
        _horaFimError = horaFimErr;
      });
      // Toast para primeiro erro
      if (spaceErr) {
        AppToast.show(context, 'Selecione ao menos um espaço.', type: ToastType.warning);
        Scrollable.ensureVisible(_spaceSectionKey.currentContext!,
            duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      } else if (dateErr) {
        AppToast.show(context, 'Selecione uma data para o evento.', type: ToastType.warning);
        Scrollable.ensureVisible(_dateSectionKey.currentContext!,
            duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      } else if (horaInicioErr) {
        AppToast.show(context, 'Selecione o horário de início.', type: ToastType.warning);
        Scrollable.ensureVisible(_horaInicioSectionKey.currentContext!,
            duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      } else {
        AppToast.show(context, 'Selecione o horário de término.', type: ToastType.warning);
        final ctx = _horaFimSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        }
      }
      return;
    }

    context.push(
      '/tabs/home/eventos/solicitar/${widget.parkId}/detalhes',
      extra: {
        'parkId': widget.parkId,
        'spaceIds': _selectedSpaceIds.toList(),
        'data': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'horaInicio': _horaInicio!,
        'horaFim': _horaFim!,
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
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Solicitar Evento',
          style: GoogleFonts.poppins(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // Banner antecedência
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Solicitações com mínimo de $_minDaysAhead dias de antecedência.',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: const Color(0xFF5D4037),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Seção: Espaços
                _SectionLabel(
                  key: _spaceSectionKey,
                  label: 'Onde: Espaços',
                  hasError: _spaceError,
                ),
                const SizedBox(height: 12),
                _buildSpacesSection(),

                const SizedBox(height: 24),

                // Seção: Data
                _SectionLabel(
                  key: _dateSectionKey,
                  label: 'Quando: Data do evento',
                  hasError: _dateError,
                ),
                const SizedBox(height: 12),
                _CalendarCard(
                  displayMonth: _displayMonth,
                  selectedDate: _selectedDate,
                  minDate: _minDate,
                  maxDate: _maxDate,
                  onPrevMonth: _prevMonth,
                  onNextMonth: _nextMonth,
                  hasError: _dateError,
                  onDateSelected: (d) {
                    setState(() {
                      _selectedDate = d;
                      _dateError = false;
                    });
                  },
                ),

                if (_selectedDate != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Seção: Horário início
                _SectionLabel(
                  key: _horaInicioSectionKey,
                  label: 'Horário de início',
                  hasError: _horaInicioError,
                ),
                const SizedBox(height: 12),
                _TimeChipsSection(
                  slots: _timeSlots,
                  selected: _horaInicio,
                  hasError: _horaInicioError,
                  onSelected: (t) {
                    setState(() {
                      _horaInicio = t;
                      _horaInicioError = false;
                      if (_horaFim != null && _toMin(_horaFim!) <= _toMin(t)) {
                        _horaFim = null;
                      }
                    });
                  },
                ),

                // Seção: Horário término (aparece só após início ser escolhido)
                if (_horaInicio != null) ...[
                  const SizedBox(height: 24),
                  _SectionLabel(
                    key: _horaFimSectionKey,
                    label: 'Horário de término',
                    hasError: _horaFimError,
                  ),
                  const SizedBox(height: 12),
                  _TimeChipsSection(
                    slots: _endOptions,
                    selected: _horaFim,
                    hasError: _horaFimError,
                    onSelected: (t) => setState(() {
                      _horaFim = t;
                      _horaFimError = false;
                    }),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Botão Continuar
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            child: FilledButton(
              onPressed: _continue,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSpacesSection() {
    if (_isLoadingSpaces) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: _green),
        ),
      );
    }

    if (_spaces.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Nenhum espaço disponível para este parque.',
          style: GoogleFonts.poppins(fontSize: 13, color: _gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _spaces.map((space) {
        final selected = _selectedSpaceIds.contains(space.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedSpaceIds.remove(space.id);
              } else {
                _selectedSpaceIds.add(space.id);
                _spaceError = false;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _green : _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _green,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  space.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _green,
                  ),
                ),
                Text(
                  '${space.maxCapacity} pessoas',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: selected ? Colors.white.withValues(alpha: 0.8) : _gray,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.label, this.hasError = false});
  final String label;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: hasError ? Colors.red.shade600 : _dark,
      ),
    );
  }
}

// Calendário inline tipo grade mensal
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.displayMonth,
    required this.selectedDate,
    required this.minDate,
    required this.maxDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDateSelected,
    this.hasError = false,
  });

  final DateTime displayMonth;
  final DateTime? selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;
  final bool hasError;

  static const _weekLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(displayMonth);
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
    final startOffset = firstDay.weekday % 7; // dom=0
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final canGoPrev = DateTime(displayMonth.year, displayMonth.month - 1)
        .isAfter(DateTime(minDate.year, minDate.month - 1));
    final canGoNext = DateTime(displayMonth.year, displayMonth.month + 1)
        .isBefore(DateTime(maxDate.year, maxDate.month + 1));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? Colors.red.shade400 : _green.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho mês
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                enabled: canGoPrev,
                onTap: onPrevMonth,
              ),
              Text(
                monthLabel[0].toUpperCase() + monthLabel.substring(1),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                enabled: canGoNext,
                onTap: onNextMonth,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Labels dos dias da semana
          Row(
            children: _weekLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _gray,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 8),

          // Grade de dias
          ...List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col;
                  final dayNum = cellIndex - startOffset + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox.shrink());
                  }

                  final day = DateTime(displayMonth.year, displayMonth.month, dayNum);
                  final blocked = day.isBefore(minDate) || day.isAfter(maxDate);
                  final isSelected = selectedDate != null &&
                      day.year == selectedDate!.year &&
                      day.month == selectedDate!.month &&
                      day.day == selectedDate!.day;
                  final isToday = DateUtils.isSameDay(day, DateTime.now());

                  return Expanded(
                    child: GestureDetector(
                      onTap: blocked ? null : () => onDateSelected(day),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected ? _green : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(color: _green.withValues(alpha: 0.4), width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dayNum',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : blocked
                                    ? _disabled
                                    : _dark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? _green.withValues(alpha: 0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? _green : _disabled,
          size: 22,
        ),
      ),
    );
  }
}

// Grid de chips de horário agrupado por período
class _TimeChipsSection extends StatelessWidget {
  const _TimeChipsSection({
    required this.slots,
    required this.selected,
    required this.onSelected,
    this.hasError = false,
  });

  final List<String> slots;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool hasError;

  static const _periods = [
    _Period('Manhã', 7, 12),
    _Period('Tarde', 12, 18),
    _Period('Noite', 18, 23),
  ];

  @override
  Widget build(BuildContext context) {
    final groups = <_Period, List<String>>{};
    for (final p in _periods) {
      groups[p] = slots.where((t) {
        final h = int.parse(t.split(':')[0]);
        return h >= p.startH && h < p.endH;
      }).toList();
    }

    final visiblePeriods = _periods.where((p) => groups[p]!.isNotEmpty).toList();

    if (visiblePeriods.isEmpty) {
      return Text(
        'Nenhum horário disponível',
        style: GoogleFonts.poppins(fontSize: 13, color: _gray),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visiblePeriods.map((period) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: groups[period]!.map((slot) {
                  final isSelected = selected == slot;
                  return GestureDetector(
                    onTap: () => onSelected(slot),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? _green
                              : hasError
                                  ? Colors.red.shade400
                                  : _green.withValues(alpha: 0.4),
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _green.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        slot,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _green,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Period {
  const _Period(this.label, this.startH, this.endH);
  final String label;
  final int startH;
  final int endH;
}
