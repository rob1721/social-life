import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

enum Participation { going, declined, none }

/// Evento del calendario. Documento: `circles/{circleId}/events/{eventId}`.
///
/// Solo el creador (`ownerId`) puede editarlo o borrarlo. Los demás miembros
/// del círculo solo pueden cambiar su propia participación.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.circleId,
    required this.ownerId,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.description = '',
    this.location = '',
    this.allDay = false,
    this.participantIds = const [],
    this.declinedIds = const [],
    this.lastActivityAt,
    this.lastActivityBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Duración máxima permitida. Permite consultar por `startAt` con un margen
  /// fijo hacia atrás y aun así encontrar eventos de varios días.
  static const Duration maxDuration = Duration(days: 31);

  final String id;
  final String circleId;
  final String ownerId;
  final String title;
  final String description;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final List<String> participantIds;
  final List<String> declinedIds;

  /// Última actividad (creación, edición, foto, comentario). Se usa para
  /// calcular notificaciones no vistas sin necesidad de Cloud Functions.
  final DateTime? lastActivityAt;
  final String? lastActivityBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get key => '${circleId}_$id';

  bool isPast([DateTime? now]) => endAt.isBefore(now ?? DateTime.now());

  bool overlaps(DateTime from, DateTime to) =>
      startAt.isBefore(to) && !endAt.isBefore(from);

  Participation participationOf(String uid) {
    if (participantIds.contains(uid)) return Participation.going;
    if (declinedIds.contains(uid)) return Participation.declined;
    return Participation.none;
  }

  factory CalendarEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final start = requiredDate(d['startAt']);
    return CalendarEvent(
      id: doc.id,
      circleId:
          d['circleId'] as String? ?? doc.reference.parent.parent?.id ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      location: d['location'] as String? ?? '',
      startAt: start,
      endAt: dateFromFirestore(d['endAt']) ?? start,
      allDay: d['allDay'] as bool? ?? false,
      participantIds: stringList(d['participantIds']),
      declinedIds: stringList(d['declinedIds']),
      lastActivityAt: dateFromFirestore(d['lastActivityAt']),
      lastActivityBy: d['lastActivityBy'] as String?,
      createdAt: dateFromFirestore(d['createdAt']),
      updatedAt: dateFromFirestore(d['updatedAt']),
    );
  }

  /// Campos editables por el creador.
  Map<String, dynamic> toEditableMap() => {
    'title': title,
    'description': description,
    'location': location,
    'startAt': Timestamp.fromDate(startAt),
    'endAt': Timestamp.fromDate(endAt),
    'allDay': allDay,
  };
}
