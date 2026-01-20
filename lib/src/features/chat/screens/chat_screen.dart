import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../models/chat_room.dart';
import '../providers/room_providers.dart';

enum ConnectionStatus { connecting, connected, disconnected }

class ChatScreen extends ConsumerStatefulWidget {
  final ChatRoom room;

  const ChatScreen({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  StreamSubscription? _messageSubscription;
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;
  bool _isLoading = true;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _showFormatting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - refresh connection
      _loadMessages(); // Fetch any missed messages
      _subscribeToMessages(); // Re-establish realtime connection
    }
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      var records = await service.getMessages(widget.room.id);
      
      // We want to load latest messages first. 
      // If service returns Oldest->Newest (standard), we keep it.
      // If service returns Newest->Oldest, we reverse it. 
      // Assuming server sorts by created ascending (Oldest first), 
      // we need to reverse the list so current[0] is the NEWEST message
      // because our ListView will be reverse: true (bottom-up).
      
      // Wait, let's verify sort in service. 
      // Service uses `sort: 'created'`. This is ascending (Oldest -> Newest).
      // So records are [Oldest, ..., Newest].
      
      // For reverse ListView:
      // Index 0 is bottom (Visual End).
      // We want Newest at Index 0.
      // So we must REVERSE the list: [Newest, ..., Oldest].
      
      final messages = records.reversed.map((r) => r.toJson()).toList();
      
      ref.read(roomMessagesProvider.notifier).state = messages;
       // No need to scroll, reverse list starts at bottom (index 0)
    } catch (e) {
      // Keep silent for now to avoid breaking UI
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribeToMessages() async {
    // Cancel existing subscription to avoid duplicates/leaks
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    
    if (mounted) setState(() => _connectionStatus = ConnectionStatus.connecting);

    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      
      // If we reach here successfully, we are essentially connected/subscribing
      if (mounted) setState(() => _connectionStatus = ConnectionStatus.connected);

      _messageSubscription = service
          .subscribeToRoomMessages(widget.room.id)
          .listen((record) {
        final current = ref.read(roomMessagesProvider);
        
        // Prevent duplicates: Check if we already have this message ID
        if (current.any((msg) => msg['id'] == record.id)) {
          return;
        }

        // New message arrives. 
        // Current state: [Newest, ..., Oldest]
        // We want new message at START: [New Message, Newest, ..., Oldest]
        ref.read(roomMessagesProvider.notifier).state = [record.toJson(), ...current];
         // Auto-scroll happens naturally in reverse list as item is inserted at 0
      }, onError: (e) {
        debugPrint('Realtime subscription error: $e');
        if (mounted) setState(() => _connectionStatus = ConnectionStatus.disconnected);
        // Auto-reconnect on error
        if (mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _subscribeToMessages();
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to start subscription: $e');
      if (mounted) setState(() => _connectionStatus = ConnectionStatus.disconnected);
      // Retry initial connection failure
      if (mounted) {
        Future.delayed(const Duration(seconds: 5), () {
           if (mounted) _subscribeToMessages();
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    
    // Optimistic UI Data preparation
    final user = ref.read(currentUserProvider);
    // Use user nickname or ID as fallback
    final nickname = ref.read(userNicknameProvider) ?? user?.data['nickname'] ?? 'Anonymous';
    final htmlContent = _markdownToHtml(content);
    // Use a unique temp ID
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    
    final optimisticMessage = {
      'id': tempId,
      'content': htmlContent,
      'created': DateTime.now().toIso8601String(),
      'updated': DateTime.now().toIso8601String(),
      'collectionId': 'Messages',
      'collectionName': 'Messages',
      'expand': {
        'Sender': {
          'nickname': nickname,
          'id': user?.id ?? '',
        }
      },
      'Sender': user?.id ?? '',
      'Room': widget.room.id,
    };

    // Apply Optimistic Update
    // [New Message, Newest, ..., Oldest]
    ref.read(roomMessagesProvider.notifier).update((state) => [optimisticMessage, ...state]);
     // Auto-scroll happens naturally in reverse list as item is inserted at 0
     _scrollToBottom();

    try {
      final service = await ref.read(pocketbaseServiceProvider.future);
      // Actual network request
      final record = await service.sendMessage(
        roomId: widget.room.id,
        content: htmlContent,
      );
      
      // Success: Replace temp message with real record
      if (mounted) {
        ref.read(roomMessagesProvider.notifier).update((state) {
          // Check if real message already added via subscription
          if (state.any((msg) => msg['id'] == record.id)) {
            return state.where((msg) => msg['id'] != tempId).toList();
          }
          
          return state.map((msg) {
            // Replace the specific temp message
            if (msg['id'] == tempId) {
                return record.toJson();
            }
            return msg;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
         // Failure: Remove the optimistic message
         ref.read(roomMessagesProvider.notifier).update((state) => 
            state.where((msg) => msg['id'] != tempId).toList()
         );
      
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $errorMsg'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
        // Restore text to controller so user doesn't lose it
         _messageController.text = content;
      }
    }
  }

  void _scrollToBottom() {
    // With reverse: true, 0 is the logical bottom (start of list)
    // We mainly use this to ensure we're at the very bottom when user sends a message
    // or when we first load.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _wrapText(String openTag, String closeTag) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    if (selection.start == selection.end) {
      return;
    }
    
    final selectedText = text.substring(selection.start, selection.end);
    final wrappedText = '$openTag$selectedText$closeTag';
    
    final newText = text.replaceRange(selection.start, selection.end, wrappedText);
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(
      offset: selection.start + wrappedText.length,
    );
  }

  void _toggleBold() {
    _wrapText('**', '**');
    setState(() => _isBold = !_isBold);
  }

  void _toggleItalic() {
    _wrapText('*', '*');
    setState(() => _isItalic = !_isItalic);
  }

  void _toggleUnderline() {
    _wrapText('__', '__');
    setState(() => _isUnderline = !_isUnderline);
  }

  String _markdownToHtml(String markdown) {
    String html = markdown;
    
    // Replace **bold** with <strong>bold</strong>
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );
    
    // Replace __underline__ with <u>underline</u>
    html = html.replaceAllMapped(
      RegExp(r'__(.*?)__'),
      (match) => '<u>${match.group(1)}</u>',
    );
    
    // Replace *italic* with <em>italic</em>
    // Use negative lookbehind to avoid replacing bold markdown
    html = html.replaceAllMapped(
      RegExp(r'(?<!\*)\*((?!\*).+?)(?<!\*)\*(?!\*)'),
      (match) => '<em>${match.group(1)}</em>',
    );
    
    // Replace line breaks with <br>
    html = html.replaceAll('\n', '<br>');
    
    return html;
  }

  Widget _buildFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.glassAccent.withOpacity(0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(
                      color: AppTheme.glassAccent.withOpacity(0.6),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? AppTheme.glassAccent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.glassAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppTheme.glassAccent,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon!'),
        backgroundColor: AppTheme.darkSurfaceVariant,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _manualReload() {
    _loadMessages();
    _subscribeToMessages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reloading chat...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) {
        return 'now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return dateTime.toString().split(' ')[0];
      }
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter messages to only show ones for this room (prevents stale data flash)
    // and sort by creation time to ensuring correct order
    final allMessages = ref.watch(roomMessagesProvider);
    final messages = allMessages
        .where((m) => m['Room'] == widget.room.id)
        .toList();
            
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurfaceVariant,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.glassAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.room.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _connectionStatus == ConnectionStatus.connected
                      ? Colors.green
                      : _connectionStatus == ConnectionStatus.connecting
                        ? Colors.orange
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _connectionStatus == ConnectionStatus.connected
                      ? '${widget.room.memberCount} members'
                      : _connectionStatus == ConnectionStatus.connecting
                        ? 'Connecting...'
                        : 'Offline',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  color: AppTheme.glassAccent,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.glassAccent),
              onPressed: _manualReload,
              tooltip: 'Reload',
            ),
        ],
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
            mainAxisSize: MainAxisSize.max,
            children: [
              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Start from bottom
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.isEmpty ? 1 : messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                       // This is now the TOP item (visually) because of reverse:true
                       // We show the Welcome message at the very end of the list (top)
                      return Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.glassAccent,
                                  width: 2,
                                ),
                              ),
                              // child: Icon(
                              //   Icons.chat_bubble_outline,
                              //   size: 32,
                              //   color: AppTheme.glassAccent.withValues(alpha: 0.8),
                              // ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome to ${widget.room.name}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }
                    
                    final message = messages[index];
                    final content = message['content']?.toString() ?? '';
                    final senderId = message['Sender']?.toString() ?? '';
                    final senderNickname = message['expand']?['Sender']?['nickname']?.toString() ?? senderId;
                    final isMe = currentUserId != null && senderId == currentUserId;
                    final timestamp = message['created']?.toString() ?? '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Sender name and time
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4, left: 12),
                                child: Text(
                                  senderNickname,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppTheme.glassAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            // Message bubble
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppTheme.glassAccent.withOpacity(0.85)
                                    : AppTheme.darkSurfaceVariant.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMe
                                      ? AppTheme.glassAccent.withOpacity(0.3)
                                      : AppTheme.border.withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Html(
                                data: content,
                                shrinkWrap: true,
                                style: {
                                  'body': Style(
                                    color: isMe ? AppTheme.darkBg : AppTheme.textPrimary,
                                    fontSize: FontSize(16),
                                    lineHeight: LineHeight(1.4),
                                    margin: Margins.zero,
                                    padding: HtmlPaddings.zero,
                                  ),
                                  'p': Style(
                                    margin: Margins.zero,
                                    padding: HtmlPaddings.zero,
                                  ),
                                },
                              ),
                            ),
                            // Time
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
                              child: Text(
                                _formatTime(timestamp),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondary.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Message input - fixed at bottom
              SingleChildScrollView(
                reverse: true,
                physics: const NeverScrollableScrollPhysics(),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    8 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceVariant.withOpacity(0.5),
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.border.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Formatting toolbar (if visible)
                      if (_showFormatting) ...[
                        // Media Buttons
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.glassAccent.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMediaButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'Camera',
                                onTap: _showComingSoon,
                              ),
                              _buildMediaButton(
                                icon: Icons.image_rounded,
                                label: 'Gallery',
                                onTap: _showComingSoon,
                              ),
                              _buildMediaButton(
                                icon: Icons.insert_drive_file_rounded,
                                label: 'File',
                                onTap: _showComingSoon,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Formatting Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.glassAccent.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildFormatButton(
                                icon: Icons.format_bold,
                                isActive: _isBold,
                                onTap: _toggleBold,
                                tooltip: 'Bold (**text**)',
                              ),
                              const SizedBox(width: 4),
                              _buildFormatButton(
                                icon: Icons.format_italic,
                                isActive: _isItalic,
                                onTap: _toggleItalic,
                                tooltip: 'Italic (*text*)',
                              ),
                              const SizedBox(width: 4),
                              _buildFormatButton(
                                icon: Icons.format_underlined,
                                isActive: _isUnderline,
                                onTap: _toggleUnderline,
                                tooltip: 'Underline (__text__)',
                              ),
                              const Spacer(),
                              Text(
                                'Markdown formatting',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondary.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Message input row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Attachment/Format Toggle button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showFormatting = !_showFormatting;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _showFormatting 
                                  ? AppTheme.glassAccent.withOpacity(0.2) 
                                  : AppTheme.darkSurface.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: _showFormatting
                                  ? Border.all(color: AppTheme.glassAccent.withOpacity(0.5), width: 1)
                                  : null,
                              ),
                              child: Icon(
                                _showFormatting ? Icons.close : Icons.add,
                                size: 22,
                                color: _showFormatting 
                                  ? AppTheme.glassAccent 
                                  : AppTheme.textSecondary.withOpacity(0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Message input field
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                // color: AppTheme.darkSurface.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.glassAccent.withOpacity(0.15),
                                  width: 0.8,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: TextStyle(
                                    color: AppTheme.textSecondary.withOpacity(0.5),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                                maxLines: null,
                                minLines: 1,
                                textInputAction: TextInputAction.newline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Send button
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.glassAccent,
                                    AppTheme.glassAccentSecondary,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.glassAccent.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
