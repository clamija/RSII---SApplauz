import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ColorCodedCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Mapirani broj termina po danu (ključ je samo datum: yyyy-mm-dd).
  final Map<DateTime, int> dayCounts;

  const ColorCodedCalendarDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.dayCounts,
  });

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required Map<DateTime, int> dayCounts,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => ColorCodedCalendarDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        dayCounts: dayCounts,
      ),
    );
  }

  @override
  State<ColorCodedCalendarDialog> createState() => _ColorCodedCalendarDialogState();
}

class _ColorCodedCalendarDialogState extends State<ColorCodedCalendarDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(widget.initialDate);
    _focusedDay = _selectedDay;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _countFor(DateTime day) => widget.dayCounts[_dateOnly(day)] ?? 0;

  Color _bgForCount(BuildContext context, int count) {
    final base = Theme.of(context).colorScheme.primary;
    // Pravilo:
    // - tamnije = više termina (>= 3 termina tog dana)
    // - svjetlije = manje termina (< 3 termina tog dana)
    // Napomena: base boja brenda je tamna, pa "samo alpha" zna izgledati tamno.
    // Zato blendamo sa bijelom radi jasne vizuelne razlike.
    const lightT = 0.15; // svijetlo
    const darkT = 0.85; // tamno
    final t = count >= 3 ? darkT : lightT;
    return Color.lerp(Colors.white, base, t)!;
  }

  Color _textForBg(Color bg) {
    return bg.computeLuminance() < 0.45 ? Colors.white : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final first = _dateOnly(widget.firstDate);
    final last = _dateOnly(widget.lastDate);

    return AlertDialog(
      title: const Text('Odaberi datum'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              firstDay: first,
              lastDay: last,
              focusedDay: _focusedDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = _dateOnly(selectedDay);
                  _focusedDay = focusedDay;
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final count = _countFor(day);
                  final bg = _bgForCount(context, count);
                  final txt = _textForBg(bg);
                  return _dayCell(context, day, bg, txt);
                },
                todayBuilder: (context, day, focusedDay) {
                  final count = _countFor(day);
                  final bg = _bgForCount(context, count);
                  final border = Theme.of(context).colorScheme.primary;
                  final txt = _textForBg(bg);
                  return _dayCell(context, day, bg, txt, border: border, borderWidth: 2);
                },
                selectedBuilder: (context, day, focusedDay) {
                  final bg = Theme.of(context).colorScheme.primary;
                  return _dayCell(context, day, bg, Colors.white);
                },
                outsideBuilder: (context, day, focusedDay) {
                  return Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _legend(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedDay),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    Color bg,
    Color textColor, {
    Color? border,
    double borderWidth = 1,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border != null ? Border.all(color: border, width: borderWidth) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final base = Theme.of(context).colorScheme.primary;
    const lightT = 0.15;
    const darkT = 0.85;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legenda:',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendSwatch(Color.lerp(Colors.white, base, lightT)!),
            const SizedBox(width: 8),
            const Expanded(child: Text('Svjetlije = manje od 3 termina')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendSwatch(Color.lerp(Colors.white, base, darkT)!),
            const SizedBox(width: 8),
            const Expanded(child: Text('Tamnije = 3 ili više termina')),
          ],
        ),
      ],
    );
  }

  Widget _legendSwatch(Color c) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}

