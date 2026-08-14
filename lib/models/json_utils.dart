import 'package:cloud_firestore/cloud_firestore.dart';

/// Small tolerant readers for Firestore maps.
///
/// Documents are written by three different clients (the Flutter app, the web
/// simulator and the Node worker), so a field can legitimately be missing or
/// arrive as a different numeric type than we expect. Parsing must never throw
/// -- a single malformed document should not kill the whole snapshot stream.

DateTime? asDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

String asString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  return fallback;
}

String? asStringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  return fallback;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<int> asIntList(Object? value) {
  if (value is! List) return const [];
  return value.map(asIntOrNull).whereType<int>().toList();
}
