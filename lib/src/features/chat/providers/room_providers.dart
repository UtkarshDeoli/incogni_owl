import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_room.dart';

// List of all rooms provider
final roomsProvider = StateProvider<List<ChatRoom>>((ref) {
  return [];
});

// Filtered rooms based on search query
final filteredRoomsProvider = StateProvider<List<ChatRoom>>((ref) {
  return [];
});

// Current search query provider
final roomSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

// Room creation dialog visibility
final showCreateRoomDialogProvider = StateProvider<bool>((ref) {
  return false;
});

// Currently selected room provider
final selectedRoomProvider = StateProvider<ChatRoom?>((ref) {
  return null;
});

// Room messages provider
final roomMessagesProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  return [];
});

// Loading state for rooms
final roomsLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

// Error message for rooms
final roomsErrorProvider = StateProvider<String?>((ref) {
  return null;
});
