import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_calendario/core/calendar_window.dart';

void main() {
  group('CalendarWindow', () {
    // Viernes 23/10/2026.
    final window = CalendarWindow(DateTime(2026, 10, 23, 15, 30));

    test('cubre 2 semanas atrás y 3 adelante en semanas completas', () {
      expect(window.weekCount, 6);
      expect(window.start, DateTime(2026, 10, 5)); // lunes
      expect(window.end, DateTime(2026, 11, 16)); // lunes, exclusivo
      expect(window.days, hasLength(42));
      expect(window.days.first.weekday, DateTime.monday);
      expect(window.days.last.weekday, DateTime.sunday);
    });

    test('incluye hoy', () {
      expect(
        window.days.any((d) => isSameDay(d, DateTime(2026, 10, 23))),
        isTrue,
      );
    });

    test('se puede desplazar para llegar a diciembre', () {
      final moved = window.shiftWeeks(9);
      expect(
        moved.days.any((d) => isSameDay(d, DateTime(2026, 12, 22))),
        isTrue,
      );
    });

    test('igualdad por valor (necesaria para cachear providers)', () {
      expect(CalendarWindow(DateTime(2026, 10, 23, 8)), window);
    });
  });

  test('dayKey / parseDayKey', () {
    final d = DateTime(2026, 12, 22);
    expect(dayKey(d), '2026-12-22');
    expect(parseDayKey('2026-12-22'), d);
    expect(parseDayKey('basura'), isNull);
  });
}
