import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Colores que el usuario asigna localmente (solo en este dispositivo) a otros
/// usuarios, para distinguirlos en el calendario.
class LocalColorStore {
  LocalColorStore(this._prefs);

  static const _key = 'local_user_colors';
  final SharedPreferences _prefs;

  Map<String, int> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> save(Map<String, int> colors) =>
      _prefs.setString(_key, jsonEncode(colors));
}
