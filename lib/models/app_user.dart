import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

/// Perfil público de un usuario. Documento: `users/{uid}`.
///
/// `googleName` y `email` provienen siempre de la cuenta de Google y no son
/// editables (las reglas de Firestore lo garantizan). El usuario solo controla
/// el apodo, si quiere mostrarlo, su avatar y su color de post-it.
class AppUser {
  const AppUser({
    required this.uid,
    required this.googleName,
    required this.email,
    this.googlePhotoUrl,
    this.nickname,
    this.showNickname = false,
    this.avatarUrl,
    this.colorValue = defaultColorValue,
    this.createdAt,
    this.updatedAt,
  });

  static const int defaultColorValue = 0xFFFFE082;

  final String uid;
  final String googleName;
  final String email;
  final String? googlePhotoUrl;
  final String? nickname;
  final bool showNickname;
  final String? avatarUrl;
  final int colorValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Nombre que se muestra en listas y en el calendario.
  String get displayName {
    final nick = nickname?.trim();
    if (showNickname && nick != null && nick.isNotEmpty) return nick;
    return googleName;
  }

  String? get photoUrl => avatarUrl ?? googlePhotoUrl;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      googleName: d['googleName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      googlePhotoUrl: d['googlePhotoUrl'] as String?,
      nickname: d['nickname'] as String?,
      showNickname: d['showNickname'] as bool? ?? false,
      avatarUrl: d['avatarUrl'] as String?,
      colorValue: (d['colorValue'] as num?)?.toInt() ?? defaultColorValue,
      createdAt: dateFromFirestore(d['createdAt']),
      updatedAt: dateFromFirestore(d['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'uid': uid,
    'googleName': googleName,
    'email': email,
    'googlePhotoUrl': googlePhotoUrl,
    'nickname': nickname,
    'showNickname': showNickname,
    'avatarUrl': avatarUrl,
    'colorValue': colorValue,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
