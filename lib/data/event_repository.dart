import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';

import '../models/calendar_event.dart';
import '../models/event_post.dart';
import '../models/event_user_state.dart';
import 'firestore_paths.dart';

class EventRepository {
  EventRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _events(String circleId) =>
      _db.collection(FirestorePaths.circleEvents(circleId));

  DocumentReference<Map<String, dynamic>> _event(String circleId, String id) =>
      _events(circleId).doc(id);

  CollectionReference<Map<String, dynamic>> _posts(
    String circleId,
    String id,
  ) => _db.collection(FirestorePaths.eventPosts(circleId, id));

  /// Eventos de todos los círculos dados que se superponen con [from, to).
  /// Se hace una consulta por círculo (las reglas validan la membresía por la
  /// ruta) y se combinan los resultados.
  Stream<List<CalendarEvent>> watchEventsInRange({
    required List<String> circleIds,
    required DateTime from,
    required DateTime to,
  }) {
    if (circleIds.isEmpty) return Stream.value(const []);
    final queryFrom = from.subtract(CalendarEvent.maxDuration);
    final streams = circleIds.map(
      (circleId) => _events(circleId)
          .where(
            'startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(queryFrom),
          )
          .where('startAt', isLessThan: Timestamp.fromDate(to))
          .orderBy('startAt')
          .snapshots()
          .map((s) => s.docs.map(CalendarEvent.fromDoc).toList()),
    );
    return Rx.combineLatestList(streams).map(
      (lists) =>
          lists.expand((l) => l).where((e) => e.overlaps(from, to)).toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt)),
    );
  }

  Stream<CalendarEvent?> watchEvent(String circleId, String eventId) => _event(
    circleId,
    eventId,
  ).snapshots().map((s) => s.exists ? CalendarEvent.fromDoc(s) : null);

  Future<String> createEvent(CalendarEvent event) async {
    final ref = _events(event.circleId).doc();
    await ref.set({
      ...event.toEditableMap(),
      'circleId': event.circleId,
      'ownerId': event.ownerId,
      'participantIds': [event.ownerId],
      'declinedIds': <String>[],
      'lastActivityAt': FieldValue.serverTimestamp(),
      'lastActivityBy': event.ownerId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateEvent(CalendarEvent event) =>
      _event(event.circleId, event.id).update({
        ...event.toEditableMap(),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityBy': event.ownerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteEvent(CalendarEvent event) =>
      _event(event.circleId, event.id).delete();

  Future<void> setParticipation(
    CalendarEvent event,
    String uid,
    Participation participation,
  ) {
    return _event(event.circleId, event.id).update({
      'participantIds': participation == Participation.going
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
      'declinedIds': participation == Participation.declined
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Material del evento (posts) ----------

  Stream<List<EventPost>> watchPosts(String circleId, String eventId) =>
      _posts(circleId, eventId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(EventPost.fromDoc).toList());

  Future<void> addNote(CalendarEvent event, String uid, String text) =>
      _addPost(event, uid, type: PostType.note, text: text);

  Future<void> addPhoto(
    CalendarEvent event,
    String uid,
    Uint8List bytes, {
    String caption = '',
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(
      StoragePaths.eventPhoto(event.circleId, event.id, uid, fileName),
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _addPost(
      event,
      uid,
      type: PostType.photo,
      text: caption,
      mediaUrls: [url],
    );
  }

  Future<void> _addPost(
    CalendarEvent event,
    String uid, {
    required PostType type,
    String text = '',
    List<String> mediaUrls = const [],
  }) {
    final batch = _db.batch()
      ..set(_posts(event.circleId, event.id).doc(), {
        'authorId': uid,
        'type': type.name,
        'text': text,
        'mediaUrls': mediaUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_event(event.circleId, event.id), {
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityBy': uid,
      });
    return batch.commit();
  }

  Future<void> updatePostText(
    CalendarEvent event,
    String postId,
    String text,
  ) => _posts(event.circleId, event.id).doc(postId).update({
    'text': text,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> deletePost(CalendarEvent event, String postId) =>
      _posts(event.circleId, event.id).doc(postId).delete();

  // ---------- Estado personal (visto / dejar de recordar) ----------

  Stream<Map<String, EventUserState>> watchEventStates(String uid) => _db
      .collection(FirestorePaths.userEventStates(uid))
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: EventUserState.fromDoc(d)});

  Future<void> markSeen(String uid, Iterable<CalendarEvent> events) {
    final batch = _db.batch();
    for (final e in events) {
      batch.set(
        _db.collection(FirestorePaths.userEventStates(uid)).doc(e.key),
        {'seenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    return batch.commit();
  }

  Future<void> setHidden(String uid, CalendarEvent event, bool hidden) => _db
      .collection(FirestorePaths.userEventStates(uid))
      .doc(event.key)
      .set({'hidden': hidden}, SetOptions(merge: true));
}
