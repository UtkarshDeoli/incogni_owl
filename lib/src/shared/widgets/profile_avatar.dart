import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
  final String nickname;
  final VoidCallback onLogout;

  const ProfileAvatar({
    Key? key,
    required this.nickname,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  late Color _avatarColor;

  @override
  void initState() {
    super.initState();
    _avatarColor = _generateColorFromNickname(widget.nickname);
  }

  /// Generate a consistent color based on the nickname
  Color _generateColorFromNickname(String nickname) {
    final colors = [
      const Color(0xFF00ADB5), // Teal
      const Color(0xFF00D4FF), // Cyan
      const Color(0xFF7B68EE), // Medium Slate Blue
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Turquoise
      const Color(0xFFFFD93D), // Yellow
      const Color(0xFF6BCB77), // Green
      const Color(0xFF4D96FF), // Blue
      const Color(0xFFFF9F1C), // Orange
      const Color(0xFFAA96FF), // Purple
    ];

    // Generate a deterministic index from the nickname
    int hash = 0;
    for (int i = 0; i < nickname.length; i++) {
      hash = ((hash << 5) - hash) + nickname.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }

    return colors[hash.abs() % colors.length];
  }

  void _showLogoutMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 0, 0, 0),
      items: [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 20),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFFF6B6B)),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') {
        widget.onLogout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = widget.nickname.isNotEmpty
        ? widget.nickname[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _showLogoutMenu,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _avatarColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _avatarColor.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            firstLetter,
            style: const TextStyle(
              color: Color(0xFFEEEEEE),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

