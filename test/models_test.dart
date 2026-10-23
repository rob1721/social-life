import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_calendario/models/app_user.dart';
import 'package:nuestro_calendario/models/calendar_event.dart';

void main() {
  group('AppUser.displayName', () {
    const base = AppUser(
      uid: 'u1',
      googleName: 'Ana Pérez',
      email: 'ana@gmail.com',
    );

    test('usa el nombre de Google por defecto', () {
      expect(base.displayName, 'Ana Pérez');
    });

    test('usa el apodo solo si el usuario lo activa', () {
      const withNick = AppUser(
        uid: 'u1',
        googleName: 'Ana Pérez',
        email: 'ana@gmail.com',
        nickname: 'Anita',
      );
      expect(withNick.displayName, 'Ana Pérez');

      const shown = AppUser(
        uid: 'u1',
        googleName: 'Ana Pérez',
        email: 'ana@gmail.com',
        nickname: 'Anita',
        showNickname: true,
      );
      expect(shown.displayName, 'Anita');
    });
  });

  group('CalendarEvent', () {
    final event = CalendarEvent(
      id: 'e1',
      circleId: 'c1',
      ownerId: 'u1',
      title: 'Festival',
      startAt: DateTime(2026, 12, 20, 18),
      endAt: DateTime(2026, 12, 22, 2),
      participantIds: const ['u1', 'u2'],
      declinedIds: const ['u3'],
    );

    test('detecta superposición con un día', () {
      expect(
        event.overlaps(DateTime(2026, 12, 21), DateTime(2026, 12, 22)),
        isTrue,
      );
      expect(
        event.overlaps(DateTime(2026, 12, 22), DateTime(2026, 12, 23)),
        isTrue,
      );
      expect(
        event.overlaps(DateTime(2026, 12, 23), DateTime(2026, 12, 24)),
        isFalse,
      );
      expect(
        event.overlaps(DateTime(2026, 12, 19), DateTime(2026, 12, 20)),
        isFalse,
      );
    });

    test('participación', () {
      expect(event.participationOf('u2'), Participation.going);
      expect(event.participationOf('u3'), Participation.declined);
      expect(event.participationOf('u4'), Participation.none);
    });
  });
}
