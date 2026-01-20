import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../providers/room_providers.dart';

class CreateRoomDialog extends ConsumerStatefulWidget {
  const CreateRoomDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<CreateRoomDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _passwordController;
  bool _isPasswordProtected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room name is required'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      final newRoom = await service.createRoom(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        password: _isPasswordProtected ? _passwordController.text.trim() : null,
      );

      final currentRooms = ref.read(roomsProvider);
      ref.read(roomsProvider.notifier).state = [...currentRooms, newRoom];
      ref.read(filteredRoomsProvider.notifier).state = [
        ...ref.read(filteredRoomsProvider),
        newRoom,
      ];

      if (!mounted) return;

      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room "${newRoom.name}" created successfully!'),
          backgroundColor: AppTheme.glassAccent,
        ),
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: AppTheme.glassAccent,
          width: 0.5,
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.glassAccent.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Room',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Room name
              Text(
                'Room Name',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter room name',
                  prefixIcon: const Icon(
                    Icons.label_outline,
                    color: AppTheme.glassAccent,
                  ),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),
              // Description
              Text(
                'Description (Optional)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter room description',
                  prefixIcon: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.glassAccent,
                  ),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),
              // Password protection toggle
              Row(
                children: [
                  Checkbox(
                    value: _isPasswordProtected,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() =>
                                _isPasswordProtected = value ?? false);
                          },
                    fillColor: MaterialStateProperty.all(
                      _isPasswordProtected
                          ? AppTheme.glassAccent
                          : AppTheme.border,
                    ),
                    checkColor: AppTheme.darkBg,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Password Protected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
              // Password field (shown if protected)
              if (_isPasswordProtected) ...[
                const SizedBox(height: 16),
                Text(
                  'Room Password',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppTheme.glassAccent,
                    ),
                  ),
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  enabled: !_isLoading,
                ),
              ],
              const SizedBox(height: 28),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkSurfaceVariant
                            .withOpacity(0.5),
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: AppTheme.border,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleCreateRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkSurfaceVariant
                            .withOpacity(0.7),
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: AppTheme.glassAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.glassAccent,
                                ),
                              ),
                            )
                          : const Text('Create'),
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
