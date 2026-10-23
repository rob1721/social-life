import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/circle.dart';
import 'firestore_paths.dart';

class UserRepository {
  UserRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  /// Crea el perfil y el círculo personal en el primer inicio de sesión, y en
  /// los siguientes sincroniza los datos que vienen de Google.
  Future<void> ensureProfile(User user) async {
    final ref = _userRef(user.uid);
    final snap = await ref.get();
    final googleName = user.displayName ?? user.email ?? 'Sin nombre';

    if (!snap.exists) {
      final profile = AppUser(
        uid: user.uid,
        googleName: googleName,
        email: (user.email ?? '').toLowerCase(),
        googlePhotoUrl: user.photoURL,
      );
      final personal = Circle(
        id: user.uid,
        name: 'Mi red',
        ownerId: user.uid,
        memberIds: [user.uid],
        kind: CircleKind.personal,
      );
      final batch = _db.batch()
        ..set(ref, profile.toCreateMap())
        ..set(
          _db.doc(FirestorePaths.circle(personal.id)),
          personal.toCreateMap(),
        );
      await batch.commit();
      return;
    }

    final data = snap.data()!;
    if (data['googleName'] != googleName ||
        data['googlePhotoUrl'] != user.photoURL) {
      await ref.update({
        'googleName': googleName,
        'googlePhotoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<AppUser?> watchUser(String uid) =>
      _userRef(uid)
          .snapshots()
          .map((s) => s.exists ? AppUser.fromDoc(s) : null);

  Future<void> updateProfile(
    String uid, {
    String? nickname,
    bool? showNickname,
    int? colorValue,
  }) {
    return _userRef(uid).update({
      'nickname': ?nickname,
      'showNickname': ?showNickname,
      'colorValue': ?colorValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> uploadAvatar(String uid, Uint8List bytes) async {
    final ref = _storage.ref(StoragePaths.avatar(uid));
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _userRef(uid)
        .update({'avatarUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeAvatar(String uid) => _userRef(uid)
      .update({'avatarUrl': null, 'updatedAt': FieldValue.serverTimestamp()});
}
