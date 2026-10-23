import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

enum CircleKind { personal, couple, family, friends, other }

extension CircleKindLabel on CircleKind {
  String get label => switch (this) {
    CircleKind.personal => 'Personal',
    CircleKind.couple => 'Pareja',
    CircleKind.family => 'Familia',
    CircleKind.friends => 'Amigos',
    CircleKind.other => 'Otro',
  };
}

/// Un "círculo" es una red privada (pareja, familia, amigos...).
/// Documento: `circles/{circleId}`. Cada usuario tiene un círculo personal
/// cuyo id es su propio uid.
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    this.kind = CircleKind.other,
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final CircleKind kind;
  final DateTime? createdAt;

  bool get isPersonal => kind == CircleKind.personal;

  factory Circle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Circle(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      memberIds: stringList(d['memberIds']),
      kind: CircleKind.values.asNameMap()[d['kind']] ?? CircleKind.other,
      createdAt: dateFromFirestore(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'name': name,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'kind': kind.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
