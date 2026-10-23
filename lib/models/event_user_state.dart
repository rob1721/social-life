import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

/// Estado privado de un usuario respecto a un evento.
/// Documento: `users/{uid}/eventStates/{circleId}_{eventId}`.
class EventUserState {
  const EventUserState({
    required this.eventKey,
    this.seenAt,
    this.hidden = false,
  });

  final String eventKey;

  /// Última vez que el usuario abrió el evento.
  final DateTime? seenAt;

  /// "Dejar de recordar": el evento ya no aparece en el calendario del usuario.
  final bool hidden;

  factory EventUserState.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return EventUserState(
      eventKey: doc.id,
      seenAt: dateFromFirestore(d['seenAt']),
      hidden: d['hidden'] as bool? ?? false,
    );
  }
}
