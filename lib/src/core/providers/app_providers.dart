import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pocketbase_service.dart';
import '../stores/auth_store.dart';

// Initialize PocketBase with persistent auth store
PocketBase? _pbInstance;

Future<PocketBase> _initPocketBase() async {
  if (_pbInstance != null) return _pbInstance!;
  
  final prefs = await SharedPreferences.getInstance();
  final pb = PocketBase(
    'https://incogni.utkarshdeoli.in',
    authStore: PersistentAuthStore(prefs: prefs),
  );
  
  _pbInstance = pb;
  return pb;
}

// PocketBase instance provider
final pocketbaseProvider = FutureProvider<PocketBase>((ref) async {
  return await _initPocketBase();
});

// PocketBase service provider
final pocketbaseServiceProvider = FutureProvider<PocketBaseService>((ref) async {
  final pb = await ref.watch(pocketbaseProvider.future);
  return PocketBaseService(pb: pb);
});

// Authentication state provider
final authStateProvider = StateProvider<bool>((ref) {
  return false;
});

// Current user provider
final currentUserProvider = StateProvider<RecordModel?>((ref) {
  return null;
});

// User nickname provider for anonymous chat
final userNicknameProvider = StateProvider<String?>((ref) {
  return null;
});

// Auth loading state
final authLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

// Auth error message
final authErrorProvider = StateProvider<String?>((ref) {
  return null;
});
