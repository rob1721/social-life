import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_converters.dart';

enum PostType { note, photo }

/// Material agregado a un evento (comentario/recuerdo o foto).
/// Documento: `circles/{circleId}/events/{eventId}/posts/{postId}`.
/// Solo su autor puede modificarlo o borrarlo.
class EventPost {
  const EventPost({
    required this.id,
    required this.authorId,
    required this.type,
    this.text = '',
    this.mediaUrls = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorId;
  final PostType type;
  final String text;
  final List<String> mediaUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EventPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return EventPost(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      type: PostType.values.asNameMap()[d['type']] ?? PostType.note,
      text: d['text'] as String? ?? '',
      mediaUrls: stringList(d['mediaUrls']),
      createdAt: dateFromFirestore(d['createdAt']),
      updatedAt: dateFromFirestore(d['updatedAt']),
    );
  }
}
