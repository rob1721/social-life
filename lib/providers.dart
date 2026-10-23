import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/calendar_window.dart';
import 'data/auth_service.dart';
import 'data/circle_repository.dart';
import 'data/event_repository.dart';
import 'data/local_color_store.dart';
import 'data/user_repository.dart';
import 'models/app_user.dart';
import 'models/calendar_event.dart';
import 'models/circle.dart';
import 'models/event_post.dart';
import 'models/event_user_state.dart';
import 'models/invite.dart';

// ---------- Infraestructura ----------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se sobrescribe en main()'),
);

final authServiceProvider = Provider(
  (ref) => AuthService(FirebaseAuth.instance),
);

final userRepositoryProvider = Provider(
  (ref) => UserRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);

final circleRepositoryProvider = Provider(
  (ref) => CircleRepository(FirebaseFirestore.instance),
);

final eventRepositoryProvider = Provider(
  (ref) =>
      EventRepository(FirebaseFirestore.instance, FirebaseStorage.instance),
);

// ---------- Sesión ----------

/// Usuario de Firebase. Antes de emitir un usuario se asegura de que exista su
/// perfil en Firestore (y su círculo personal).
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  final users = ref.watch(userRepositoryProvider);
  return auth.authStateChanges().asyncMap((user) async {
    if (user != null) await users.ensureProfile(user);
    return user;
  });
});

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

final userProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid),
);

final currentUserProvider = Provider<AsyncValue<AppUser?>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData(null);
  return ref.watch(userProvider(uid));
});

// ---------- Círculos e invitaciones ----------

final myCirclesProvider = StreamProvider<List<Circle>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(circleRepositoryProvider).watchMyCircles(uid);
});

final pendingInvitesProvider = StreamProvider<List<Invite>>((ref) {
  final email = ref.watch(authStateProvider).value?.email;
  if (email == null) return Stream.value(const []);
  return ref.watch(circleRepositoryProvider).watchPendingInvites(email);
});

// ---------- Eventos ----------

final _myCircleIdsProvider = Provider<List<String>?>((ref) {
  final ids = ref.watch(myCirclesProvider).value?.map((c) => c.id).toList();
  return ids?..sort();
});

final eventStatesProvider = StreamProvider<Map<String, EventUserState>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(eventRepositoryProvider).watchEventStates(uid);
});

/// Eventos de todas mis redes en un rango, excluyendo los que oculté.
final eventsInRangeProvider = StreamProvider.autoDispose
    .family<List<CalendarEvent>, DateTimeRange>((ref, range) {
      final circleIds = ref.watch(_myCircleIdsProvider);
      if (circleIds == null) return const Stream.empty();
      return ref
          .watch(eventRepositoryProvider)
          .watchEventsInRange(
            circleIds: circleIds,
            from: range.start,
            to: range.end,
          );
    });

final hiddenEventKeysProvider = Provider<Set<String>>((ref) {
  final states = ref.watch(eventStatesProvider).value ?? const {};
  return {
    for (final e in states.entries)
      if (e.value.hidden) e.key,
  };
});

final visibleEventsInRangeProvider = Provider.autoDispose
    .family<AsyncValue<List<CalendarEvent>>, DateTimeRange>((ref, range) {
      final hidden = ref.watch(hiddenEventKeysProvider);
      return ref
          .watch(eventsInRangeProvider(range))
          .whenData(
            (list) => list.where((e) => !hidden.contains(e.key)).toList(),
          );
    });

final eventProvider = StreamProvider.autoDispose
    .family<CalendarEvent?, (String circleId, String eventId)>(
      (ref, id) => ref.watch(eventRepositoryProvider).watchEvent(id.$1, id.$2),
    );

final eventPostsProvider = StreamProvider.autoDispose
    .family<List<EventPost>, (String circleId, String eventId)>(
      (ref, id) => ref.watch(eventRepositoryProvider).watchPosts(id.$1, id.$2),
    );

class CalendarWindowNotifier extends Notifier<CalendarWindow> {
  @override
  CalendarWindow build() => CalendarWindow(DateTime.now());

  void shift(int weeks) => state = state.shiftWeeks(weeks);
  void goToToday() => state = CalendarWindow(DateTime.now());
}

final calendarWindowProvider =
    NotifierProvider<CalendarWindowNotifier, CalendarWindow>(
      CalendarWindowNotifier.new,
    );

/// Eventos con actividad de otra persona que aún no he visto.
final unseenEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final window = ref.watch(calendarWindowProvider);
  final events =
      ref.watch(visibleEventsInRangeProvider(window.range)).value ?? const [];
  final states = ref.watch(eventStatesProvider).value ?? const {};
  return events.where((e) {
    if (e.lastActivityBy == null || e.lastActivityBy == uid) return false;
    final seenAt = states[e.key]?.seenAt;
    final activity = e.lastActivityAt;
    return seenAt == null || (activity != null && activity.isAfter(seenAt));
  }).toList();
});

// ---------- Colores ----------

class LocalColorsNotifier extends Notifier<Map<String, int>> {
  late final LocalColorStore _store;

  @override
  Map<String, int> build() {
    _store = LocalColorStore(ref.watch(sharedPreferencesProvider));
    return _store.load();
  }

  Future<void> setColor(String uid, Color? color) async {
    final next = {...state};
    if (color == null) {
      next.remove(uid);
    } else {
      next[uid] = color.toARGB32();
    }
    state = next;
    await _store.save(next);
  }
}

final localColorsProvider =
    NotifierProvider<LocalColorsNotifier, Map<String, int>>(
      LocalColorsNotifier.new,
    );

/// Color del post-it de un usuario: el que yo le asigné localmente o, si no,
/// el que esa persona eligió para sí.
final userColorProvider = Provider.family<Color, String>((ref, uid) {
  final local = ref.watch(localColorsProvider)[uid];
  if (local != null) return Color(local);
  final user = ref.watch(userProvider(uid)).value;
  return Color(user?.colorValue ?? AppUser.defaultColorValue);
});

const postItPalette = <Color>[
  Color(0xFFFFE082),
  Color(0xFFFFAB91),
  Color(0xFFF48FB1),
  Color(0xFFCE93D8),
  Color(0xFF9FA8DA),
  Color(0xFF81D4FA),
  Color(0xFF80CBC4),
  Color(0xFFA5D6A7),
  Color(0xFFE6EE9C),
  Color(0xFFBCAAA4),
];
