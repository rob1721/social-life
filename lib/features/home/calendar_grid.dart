import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_window.dart';
import '../../models/calendar_event.dart';
import '../../widgets/common.dart';

/// Grilla de semanas (lunes a domingo) con post-its por día.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.window,
    required this.events,
    required this.onDayTap,
    this.maxPostItsPerDay = 2,
  });

  final CalendarWindow window;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDayTap;
  final int maxPostItsPerDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final days = window.days;
    final weekdayLabels = [
      for (var i = 0; i < 7; i++)
        DateFormat.E('es').format(days[i]).substring(0, 2),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        for (var w = 0; w < window.weekCount; w++)
          Expanded(
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _DayCell(
                      day: days[w * 7 + d],
                      today: today,
                      events: _eventsOn(days[w * 7 + d]),
                      maxPostIts: maxPostItsPerDay,
                      onTap: onDayTap,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<CalendarEvent> _eventsOn(DateTime day) {
    final range = dayRange(day);
    return events.where((e) => e.overlaps(range.start, range.end)).toList();
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.events,
    required this.maxPostIts,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final List<CalendarEvent> events;
  final int maxPostIts;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = day == today;
    final isPast = day.isBefore(today);
    final extra = events.length - maxPostIts;

    return InkWell(
      onTap: () => onTap(day),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isPast
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : null,
          border: Border.all(
            color: isToday ? scheme.primary : scheme.outlineVariant,
            width: isToday ? 2 : 0.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              day.day == 1 ? DateFormat.MMMd('es').format(day) : '${day.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in events.take(maxPostIts)) PostIt(event: e),
                    if (extra > 0)
                      Text('+$extra', style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
