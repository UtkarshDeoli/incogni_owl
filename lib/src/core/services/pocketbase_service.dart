import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../features/chat/models/chat_room.dart';

class PocketBaseService {
  final PocketBase pb;

  PocketBaseService({required this.pb});

  /// Check if user is authenticated
  bool get isAuthenticated => pb.authStore.isValid;

  /// Get current user
  RecordModel? get currentUser {
    try {
      if (pb.authStore.isValid) {
        return pb.authStore.model as RecordModel?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get auth token
  String? get authToken => pb.authStore.token;

  /// Sign up new anonymous user
  Future<RecordModel> signup({
    required String nickname,
    required String password,
    String? email,
  }) async {
    try {
      // Validate input
      final nicknameError = validateNickname(nickname);
      if (nicknameError != null) {
        throw Exception(nicknameError);
      }
      final passwordError = validatePassword(password);
      if (passwordError != null) {
        throw Exception(passwordError);
      }

      final body = <String, dynamic>{
        'email': email ?? '',
        'emailVisibility': false,
        'nickname': nickname,
        'is_anonymous': true,
        'password': password,
        'passwordConfirm': password,
      };

      final record = await pb.collection('Users').create(body: body);
      print('User created: $nickname');
      return record;
    } on ClientException catch (e) {
      if (e.statusCode == 400) {
        final errorStr = e.toString();
        if (errorStr.contains('nickname')) {
          throw Exception('This nickname is already taken. Please choose another.');
        }
        if (errorStr.contains('email')) {
          throw Exception('This email is already in use.');
        }
        throw Exception('Invalid input. Please check your information.');
      } else if (e.statusCode == 409) {
        throw Exception('This nickname is already taken. Please choose another.');
      } else if (e.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      }
      throw Exception('Signup failed. Please try again.');
    } catch (e) {
      throw Exception('$e');
    }
  }

  /// Login with nickname and password
  Future<RecordModel?> login({
    required String nickname,
    required String password,
  }) async {
    try {
      final authData = await pb.collection('Users').authWithPassword(
        nickname,
        password,
      );

      print('User logged in: $nickname');
      print('Auth token: ${pb.authStore.token}');
      return authData.record;
    } on ClientException catch (e, st) {
      // PocketBase client errors (HTTP-level)
      print('PocketBase ClientException during login: ${e.toString()}');
      print(st);
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw Exception('Invalid nickname or password.');
      } else if (e.statusCode == 404) {
        throw Exception('User not found.');
      } else if (e.statusCode >= 500) {
        throw Exception('Server error (${e.statusCode}). Please try again later.');
      }
      throw Exception('Login failed (status ${e.statusCode}).');
    } on TimeoutException catch (e, st) {
      print('Timeout during login: $e');
      print(st);
      throw Exception('Request timed out. Check your network and try again.');
    } on SocketException catch (e, st) {
      print('Network error during login: $e');
      print(st);
      throw Exception('Network error. Please check your internet connection.');
    } catch (e, st) {
      print('Unexpected error during login: $e');
      print(st);
      throw Exception('Login failed. ${e.toString()}');
    }
  }

  /// Logout
  void logout() {
    try {
      pb.authStore.clear();
      print('User logged out');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Validate nickname format
  static String? validateNickname(String nickname) {
    if (nickname.isEmpty) {
      return 'Nickname cannot be empty';
    }
    if (nickname.length < 3) {
      return 'Nickname must be at least 3 characters';
    }
    if (nickname.length > 20) {
      return 'Nickname must be less than 20 characters';
    }
    if (nickname.contains(' ')) {
      return 'Nickname cannot contain spaces';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(nickname)) {
      return 'Nickname can only contain letters, numbers, underscores, and hyphens';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
  String _hashRoomPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  String _escapeFilterValue(String value) {
    return value.replaceAll('"', '\\"');
  }

  Future<List<ChatRoom>> getRooms({int page = 1, int perPage = 50}) async {
    try {
      final result = await pb.collection('Rooms').getList(
            page: page,
            perPage: perPage,
            sort: '-created',
          );

      return result.items
          .map((record) => ChatRoom.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch rooms: $e');
    }
  }

  /// Fetch rooms with search query
  Future<List<ChatRoom>> searchRooms(String query) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        return getRooms();
      }

      final safeQuery = _escapeFilterValue(trimmed);
      final filter = 'name ~ "${safeQuery}" || description ~ "${safeQuery}"';

      final records = await pb.collection('Rooms').getFullList(
            sort: '-created',
            filter: filter,
          );

      return records
          .map((record) => ChatRoom.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search rooms: $e');
    }
  }

  /// View a single room
  Future<ChatRoom> getRoom(String roomId) async {
    try {
      final record = await pb.collection('Rooms').getOne(roomId);
      return ChatRoom.fromJson(record.toJson());
    } catch (e) {
      throw Exception('Failed to fetch room: $e');
    }
  }

  /// Create a new room
  Future<ChatRoom> createRoom({
    required String name,
    String? description,
    String? password,
  }) async {
    try {
      final creator = currentUser;
      if (creator == null) {
        throw Exception('You must be logged in to create a room.');
      }

      final isProtected = password != null && password.trim().isNotEmpty;
      final body = <String, dynamic>{
        'name': name.trim(),
        'description': description?.trim(),
        'is_password_protected': isProtected,
        'password_hash': isProtected ? _hashRoomPassword(password.trim()) : null,
        'created_by': creator.id,
        'members': [creator.id],
      };

      final record = await pb.collection('Rooms').create(body: body);
      return ChatRoom.fromJson(record.toJson());
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  /// Join a room (with optional password verification)
  Future<void> joinRoom(String roomId, {String? password}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('You must be logged in to join a room.');
      }

      final roomRecord = await pb.collection('Rooms').getOne(roomId);
      final data = roomRecord.toJson();

      final isProtected = data['is_password_protected'] as bool? ?? false;
      if (isProtected) {
        final storedHash = data['password_hash'] as String?;
        if (password == null || password.trim().isEmpty) {
          throw Exception('Room password is required.');
        }
        final inputHash = _hashRoomPassword(password.trim());
        if (storedHash == null || storedHash != inputHash) {
          throw Exception('Incorrect room password.');
        }
      }

      final members = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (!members.contains(user.id)) {
        members.add(user.id);
      }

      await pb.collection('Rooms').update(roomId, body: {
        'members': members,
      });
    } catch (e) {
      throw Exception('Failed to join room: $e');
    }
  }

  /// Get messages for a room
  Future<List<RecordModel>> getMessages(String roomId) async {
    try {
      final records = await pb.collection('Messages').getFullList(
            filter: 'Room="${_escapeFilterValue(roomId)}"',
            sort: 'created',
            expand: 'Sender',
          );
      return records;
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Send a message to a room
  Future<RecordModel> sendMessage({
    required String roomId,
    required String content,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('You must be logged in to send messages.');
      }

      final body = <String, dynamic>{
        'Room': roomId,
        'Sender': user.id,
        'content': content.trim(),
      };

      final record = await pb.collection('Messages').create(body: body);
      return record;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Subscribe to room messages in real-time
  Stream<RecordModel> subscribeToRoomMessages(String roomId) {
    // Broadcaster stream ensures multiple listeners can be handled if needed, 
    // though here we use a single controller.
    final controller = StreamController<RecordModel>.broadcast();

    // Start subscription
    pb.collection('Messages').subscribe('*', (e) {
      final record = e.record;
      if (record == null) return;
      final data = record.toJson();
      if (data['Room']?.toString() == roomId) {
        if (!controller.isClosed) {
          controller.add(record);
        }
      }
    }).then((_) {
      // Subscription successful
    }).catchError((e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    });

    controller.onCancel = () {
      pb.collection('Messages').unsubscribe('*').catchError((_) {});
      controller.close();
    };

    return controller.stream;
  }
}
