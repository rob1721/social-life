import 'package:flutter/material.dart';

/// Ventana visible del calendario: semanas completas (lunes a domingo) desde
/// [weeksBefore] semanas antes de la semana del ancla hasta [weeksAfter]
/// semanas después. Con los valores por defecto son 6 semanas: -2, -1, la
/// actual, +1, +2 y +3.
@immutable
class CalendarWindow {
  CalendarWindow(DateTime anchor, {this.weeksBefore = 2, this.weeksAfter = 3})
    : anchor = dateOnly(anchor);

  final DateTime anchor;
  final int weeksBefore;
  final int weeksAfter;

  int get weekCount => weeksBefore + 1 + weeksAfter;

  DateTime get start {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day - weeksBefore * 7);
  }

  /// Exclusivo.
  DateTime get end =>
      DateTime(start.year, start.month, start.day + weekCount * 7);

  DateTimeRange get range => DateTimeRange(start: start, end: end);

  List<DateTime> get days => [
    for (var i = 0; i < weekCount * 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];

  CalendarWindow shiftWeeks(int weeks) => CalendarWindow(
    DateTime(anchor.year, anchor.month, anchor.day + weeks * 7),
    weeksBefore: weeksBefore,
    weeksAfter: weeksAfter,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarWindow &&
      other.anchor == anchor &&
      other.weeksBefore == weeksBefore &&
      other.weeksAfter == weeksAfter;

  @override
  int get hashCode => Object.hash(anchor, weeksBefore, weeksAfter);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTimeRange dayRange(DateTime day) {
  final start = dateOnly(day);
  return DateTimeRange(
    start: start,
    end: DateTime(start.year, start.month, start.day + 1),
  );
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? parseDayKey(String key) {
  final parsed = DateTime.tryParse(key);
  return parsed == null ? null : dateOnly(parsed);
}
