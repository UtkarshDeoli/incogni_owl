import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../models/chat_room.dart';
import '../providers/room_providers.dart';
import '../widgets/create_room_dialog.dart';
import 'chat_screen.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRooms();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    ref.read(roomsLoadingProvider.notifier).state = true;
    ref.read(roomsErrorProvider.notifier).state = null;

    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      final rooms = await service.getRooms();
      ref.read(roomsProvider.notifier).state = rooms;
      ref.read(filteredRoomsProvider.notifier).state = rooms;
    } catch (e) {
      ref.read(roomsErrorProvider.notifier).state =
          e.toString().replaceAll('Exception: ', '');
    } finally {
      ref.read(roomsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _handleSearch(String query) async {
    ref.read(roomSearchQueryProvider.notifier).state = query;
    ref.read(roomsLoadingProvider.notifier).state = true;
    ref.read(roomsErrorProvider.notifier).state = null;

    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      final rooms = await service.searchRooms(query);
      ref.read(filteredRoomsProvider.notifier).state = rooms;
    } catch (e) {
      ref.read(roomsErrorProvider.notifier).state =
          e.toString().replaceAll('Exception: ', '');
    } finally {
      ref.read(roomsLoadingProvider.notifier).state = false;
    }
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateRoomDialog(),
    );
  }

  Future<void> _handleLogout() async {
    // Clear auth state
    ref.read(authStateProvider.notifier).state = false;
    ref.read(userNicknameProvider.notifier).state = null;

    // Get PocketBase instance and logout
    try {
      final pbAsync = ref.read(pocketbaseProvider);
      pbAsync.whenData((pb) {
        pb.authStore.clear();
      });
    } catch (e) {
      // Ignore errors
    }

    // Navigate back to login
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _joinRoom(ChatRoom room) async {
    if (room.isPasswordProtected) {
      _showPasswordDialog(room);
    } else {
      await _attemptJoinRoom(room);
    }
  }

  void _showPasswordDialog(ChatRoom room) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Enter Room Password'),
        content: TextField(
          controller: passwordController,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text.trim();
              Navigator.pop(context);
              _attemptJoinRoom(room, password: password);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptJoinRoom(ChatRoom room, {String? password}) async {
    // If room is public, navigate immediately while joining in background
    if (password == null) {
      _navigateToChat(room);
      try {
        final service = await ref.read(pocketbaseServiceProvider.future);
        await service.joinRoom(room.id);
      } catch (e) {
        // Failing to join usually isn't fatal as long as we can read messages (public read)
        // If write is protected, sending will fail there. 
        // We log it but don't block navigation.
        debugPrint('Join room non-fatal error: $e');
      }
      return;
    }

    // Password protected rooms still need verification
    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      await service.joinRoom(room.id, password: password);
      if (!mounted) return;
      _navigateToChat(room);
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  void _navigateToChat(ChatRoom room) {
    ref.read(selectedRoomProvider.notifier).state = room;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = ref.watch(filteredRoomsProvider);
    final userNickname = ref.watch(userNicknameProvider) ?? 'Anonymous';
    final isLoading = ref.watch(roomsLoadingProvider);
    final errorMessage = ref.watch(roomsErrorProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurfaceVariant,
        elevation: 0,
        title: const Text('Chat Rooms'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ProfileAvatar(
              nickname: userNickname,
              onLogout: _handleLogout,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.glassAccentSecondary,
        onPressed: _showCreateRoomDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.darkBg,
                  AppTheme.darkSurfaceVariant.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _handleSearch,
                  decoration: InputDecoration(
                    hintText: 'Search rooms...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.glassAccent,
                    ),
                  ),
                ),
              ),
              // Room list
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.glassAccent,
                        ),
                      )
                    : errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: AppTheme.textSecondary.withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _loadRooms,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredRooms.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No rooms found',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredRooms.length,
                                itemBuilder: (context, index) {
                                  final room = filteredRooms[index];
                                  return _buildRoomCard(room);
                                },
                              ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(ChatRoom room) {
    return GestureDetector(
      onTap: () => _joinRoom(room),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room name and lock icon
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (room.isPasswordProtected)
                    const Icon(
                      Icons.lock,
                      size: 18,
                      color: AppTheme.glassAccent,
                    ),
                ],
              ),
              if (room.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  room.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              // Member count
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${room.memberCount} members',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
