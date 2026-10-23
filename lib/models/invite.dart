import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

enum InviteStatus { pending, accepted, declined }

/// Invitación a un círculo por email. Documento: `invites/{circleId}_{email}`.
/// El id determinista permite a las reglas verificar que quien se une a un
/// círculo realmente fue invitado.
class Invite {
  const Invite({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.email,
    required this.invitedBy,
    required this.invitedByName,
    this.status = InviteStatus.pending,
    this.createdAt,
  });

  final String id;
  final String circleId;
  final String circleName;
  final String email;
  final String invitedBy;
  final String invitedByName;
  final InviteStatus status;
  final DateTime? createdAt;

  static String idFor(String circleId, String email) =>
      '${circleId}_${email.trim().toLowerCase()}';

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Invite(
      id: doc.id,
      circleId: d['circleId'] as String? ?? '',
      circleName: d['circleName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      invitedBy: d['invitedBy'] as String? ?? '',
      invitedByName: d['invitedByName'] as String? ?? '',
      status:
          InviteStatus.values.asNameMap()[d['status']] ?? InviteStatus.pending,
      createdAt: dateFromFirestore(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'circleId': circleId,
    'circleName': circleName,
    'email': email,
    'invitedBy': invitedBy,
    'invitedByName': invitedByName,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
