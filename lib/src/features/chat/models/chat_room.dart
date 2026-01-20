class ChatRoom {
  final String id;
  final String name;
  final String? description;
  final bool isPasswordProtected;
  final String? password;
  final DateTime createdAt;
  final int memberCount;

  ChatRoom({
    required this.id,
    required this.name,
    this.description,
    this.isPasswordProtected = false,
    this.password,
    required this.createdAt,
    this.memberCount = 0,
  });

  /// Factory constructor to create ChatRoom from JSON
  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Room',
      description: json['description'] as String?,
      isPasswordProtected:
          json['is_password_protected'] as bool? ?? json['isPasswordProtected'] as bool? ?? false,
      password: json['password_hash'] as String? ?? json['password'] as String?,
      createdAt: DateTime.parse(
        json['created'] as String? ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      memberCount: (json['members'] as List?)?.length ??
          json['memberCount'] as int? ??
          0,
    );
  }

  /// Convert ChatRoom to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_password_protected': isPasswordProtected,
      'password_hash': password,
      'created': createdAt.toIso8601String(),
      'members': List.filled(memberCount, ''),
    };
  }

  /// Create a copy of ChatRoom with modified fields
  ChatRoom copyWith({
    String? id,
    String? name,
    String? description,
    bool? isPasswordProtected,
    String? password,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
