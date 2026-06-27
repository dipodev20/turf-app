class UserModel {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? city;
  final int level;
  final double kmRan;
  final int territoriesCaptured;
  final int territoriesDefended;
  final int currentStreak;
  final int maxStreak;
  final String? clanId;
  final String? skinId;
  final String? trailId;
  final int coins;
  final bool isOnline;
  final bool shareLocation;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.city,
    this.level = 1,
    this.kmRan = 0,
    this.territoriesCaptured = 0,
    this.territoriesDefended = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.clanId,
    this.skinId,
    this.trailId,
    this.coins = 0,
    this.isOnline = false,
    this.shareLocation = true,
    required this.createdAt,
    this.lastSeenAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      coverUrl: json['cover_url'],
      bio: json['bio'],
      city: json['city'],
      level: json['level'] ?? 1,
      kmRan: (json['km_ran'] ?? 0).toDouble(),
      territoriesCaptured: json['territories_captured'] ?? 0,
      territoriesDefended: json['territories_defended'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      maxStreak: json['max_streak'] ?? 0,
      clanId: json['clan_id'],
      skinId: json['skin_id'],
      trailId: json['trail_id'],
      coins: json['coins'] ?? 0,
      isOnline: json['is_online'] ?? false,
      shareLocation: json['share_location'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'avatar_url': avatarUrl,
    'cover_url': coverUrl,
    'bio': bio,
    'city': city,
    'level': level,
    'km_ran': kmRan,
    'territories_captured': territoriesCaptured,
    'territories_defended': territoriesDefended,
    'current_streak': currentStreak,
    'max_streak': maxStreak,
    'clan_id': clanId,
    'skin_id': skinId,
    'trail_id': trailId,
    'coins': coins,
    'is_online': isOnline,
    'share_location': shareLocation,
    'created_at': createdAt.toIso8601String(),
    'last_seen_at': lastSeenAt?.toIso8601String(),
  };

  UserModel copyWith({
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    String? city,
    int? level,
    double? kmRan,
    int? territoriesCaptured,
    int? territoriesDefended,
    int? currentStreak,
    int? maxStreak,
    String? clanId,
    String? skinId,
    String? trailId,
    int? coins,
    bool? isOnline,
    bool? shareLocation,
    DateTime? lastSeenAt,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      level: level ?? this.level,
      kmRan: kmRan ?? this.kmRan,
      territoriesCaptured: territoriesCaptured ?? this.territoriesCaptured,
      territoriesDefended: territoriesDefended ?? this.territoriesDefended,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      clanId: clanId ?? this.clanId,
      skinId: skinId ?? this.skinId,
      trailId: trailId ?? this.trailId,
      coins: coins ?? this.coins,
      isOnline: isOnline ?? this.isOnline,
      shareLocation: shareLocation ?? this.shareLocation,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  // Форматировать "was online" время
  String get lastSeenText {
    if (isOnline) return 'Online';
    final seen = lastSeenAt;
    if (seen == null) return 'Offline';
    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'Long ago';
  }
}
