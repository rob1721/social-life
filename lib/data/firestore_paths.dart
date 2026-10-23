/// Rutas centralizadas de Firestore / Storage. Ver docs/ARQUITECTURA.md.
abstract final class FirestorePaths {
  static const users = 'users';
  static const circles = 'circles';
  static const invites = 'invites';
  static const events = 'events';
  static const posts = 'posts';
  static const eventStates = 'eventStates';

  static String user(String uid) => '$users/$uid';
  static String circle(String circleId) => '$circles/$circleId';
  static String circleEvents(String circleId) => '$circles/$circleId/$events';
  static String event(String circleId, String eventId) =>
      '${circleEvents(circleId)}/$eventId';
  static String eventPosts(String circleId, String eventId) =>
      '${event(circleId, eventId)}/$posts';
  static String userEventStates(String uid) => '$users/$uid/$eventStates';
}

abstract final class StoragePaths {
  static String avatar(String uid) => 'users/$uid/avatar.jpg';
  static String eventPhoto(
    String circleId,
    String eventId,
    String uid,
    String fileName,
  ) => 'circles/$circleId/events/$eventId/$uid/$fileName';
}
