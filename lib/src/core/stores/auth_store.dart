import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Custom AuthStore for PocketBase that persists to SharedPreferences
class PersistentAuthStore extends AuthStore {
  final SharedPreferences prefs;
  static const String _tokenKey = 'pb_auth_token';
  static const String _modelKey = 'pb_auth_model';

  PersistentAuthStore({required this.prefs}) {
    _loadFromStorage();
  }

  /// Load persisted auth data from storage on initialization
  void _loadFromStorage() {
    final tokenData = prefs.getString(_tokenKey);
    final modelData = prefs.getString(_modelKey);

    if (tokenData != null && modelData != null) {
      try {
        final json = jsonDecode(modelData);
        final model = RecordModel.fromJson(json);
        save(tokenData, model);
      } catch (e) {
        // Ignore parse errors
      }
    }
  }

  /// Override save to also persist to storage
  @override
  void save(String token, [dynamic model]) {
    // Save to SharedPreferences
    if (token.isNotEmpty) {
      prefs.setString(_tokenKey, token);
    } else {
      prefs.remove(_tokenKey);
    }

    if (model != null && model is RecordModel) {
      prefs.setString(_modelKey, jsonEncode(model.toJson()));
    } else {
      prefs.remove(_modelKey);
    }

    // Call parent save to update internal state
    super.save(token, model);
  }

  /// Override clear to also clear from storage
  @override
  void clear() {
    prefs.remove(_tokenKey);
    prefs.remove(_modelKey);
    super.clear();
  }
}



