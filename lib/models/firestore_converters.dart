import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Pending server timestamps arrive as null in local snapshots; fall back to
/// "now" so freshly written documents still render.
DateTime requiredDate(Object? value) =>
    dateFromFirestore(value) ?? DateTime.now();

List<String> stringList(Object? value) =>
    value is Iterable ? value.map((e) => e.toString()).toList() : <String>[];
