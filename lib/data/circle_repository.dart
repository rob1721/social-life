import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/circle.dart';
import '../models/invite.dart';
import 'firestore_paths.dart';

class CircleRepository {
  CircleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _circles =>
      _db.collection(FirestorePaths.circles);
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(FirestorePaths.invites);

  Stream<List<Circle>> watchMyCircles(String uid) => _circles
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(Circle.fromDoc).toList());

  Future<String> createCircle({
    required String ownerId,
    required String name,
    required CircleKind kind,
  }) async {
    final ref = _circles.doc();
    await ref.set(
      Circle(
        id: ref.id,
        name: name,
        ownerId: ownerId,
        memberIds: [ownerId],
        kind: kind,
      ).toCreateMap(),
    );
    return ref.id;
  }

  Future<void> invite({
    required Circle circle,
    required AppUser inviter,
    required String email,
  }) {
    final normalized = email.trim().toLowerCase();
    final invite = Invite(
      id: Invite.idFor(circle.id, normalized),
      circleId: circle.id,
      circleName: circle.name,
      email: normalized,
      invitedBy: inviter.uid,
      invitedByName: inviter.displayName,
    );
    return _invites.doc(invite.id).set(invite.toCreateMap());
  }

  Stream<List<Invite>> watchPendingInvites(String email) => _invites
      .where('email', isEqualTo: email.toLowerCase())
      .where('status', isEqualTo: InviteStatus.pending.name)
      .snapshots()
      .map((s) => s.docs.map(Invite.fromDoc).toList());

  /// Las reglas solo permiten unirse si la invitación sigue pendiente, por eso
  /// ambas escrituras van en el mismo batch.
  Future<void> acceptInvite(Invite invite, String uid) {
    final batch = _db.batch()
      ..update(_invites.doc(invite.id), {
        'status': InviteStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      })
      ..update(_circles.doc(invite.circleId), {
        'memberIds': FieldValue.arrayUnion([uid]),
      });
    return batch.commit();
  }

  Future<void> declineInvite(Invite invite) => _invites.doc(invite.id).update({
    'status': InviteStatus.declined.name,
    'respondedAt': FieldValue.serverTimestamp(),
  });

  Future<void> leaveCircle(String circleId, String uid) =>
      _circles.doc(circleId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
}
