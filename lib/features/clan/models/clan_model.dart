class ClanModel {
  final String id;
  final String name;
  final String? slogan;
  final String? flagUrl;
  final String color;
  final String bossId;
  final int memberCount;
  final int territoryCount;
  final String rank;
  final bool isOpen;
  final int maxMembers;
  final String? city;
  final String arenaMode;
  final double virtualOffsetLat;
  final double virtualOffsetLng;
  final DateTime createdAt;

  const ClanModel({
    required this.id,
    required this.name,
    this.slogan,
    this.flagUrl,
    this.color = '#5B5BD6',
    required this.bossId,
    this.memberCount = 1,
    this.territoryCount = 0,
    this.rank = 'Street Crew',
    this.isOpen = false,
    this.maxMembers = 30,
    this.city,
    this.arenaMode = 'local',
    this.virtualOffsetLat = 0,
    this.virtualOffsetLng = 0,
    required this.createdAt,
  });

  factory ClanModel.fromJson(Map<String, dynamic> json) {
    return ClanModel(
      id: json['id'],
      name: json['name'],
      slogan: json['slogan'],
      flagUrl: json['flag_url'],
      color: json['color'] ?? '#5B5BD6',
      bossId: json['boss_id'],
      memberCount: json['member_count'] ?? 1,
      territoryCount: json['territory_count'] ?? 0,
      rank: json['rank'] ?? 'Street Crew',
      isOpen: json['is_open'] ?? false,
      maxMembers: json['max_members'] ?? 30,
      city: json['city'],
      arenaMode: json['arena_mode'] as String? ?? 'local',
      virtualOffsetLat: (json['virtual_offset_lat'] as num?)?.toDouble() ?? 0,
      virtualOffsetLng: (json['virtual_offset_lng'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slogan': slogan,
    'flag_url': flagUrl,
    'color': color,
    'boss_id': bossId,
    'member_count': memberCount,
    'territory_count': territoryCount,
    'rank': rank,
    'is_open': isOpen,
    'max_members': maxMembers,
    'city': city,
      'arena_mode': arenaMode,
      'virtual_offset_lat': virtualOffsetLat,
      'virtual_offset_lng': virtualOffsetLng,
    'created_at': createdAt.toIso8601String(),
  };

  static String getRankFromTerritories(int count) {
    if (count >= 200) return 'Kingpin';
    if (count >= 100) return 'Cartel';
    if (count >= 50) return 'Gang';
    if (count >= 10) return 'Hood';
    return 'Street Crew';
  }
}

class ClanMemberModel {
  final String userId;
  final String clanId;
  final String username;
  final String? avatarUrl;
  final String role; // boss, underboss, soldier, prospect
  final double kmRan;
  final int territoriesCaptured;
  final bool isOnline;
  final DateTime joinedAt;

  const ClanMemberModel({
    required this.userId,
    required this.clanId,
    required this.username,
    this.avatarUrl,
    required this.role,
    this.kmRan = 0,
    this.territoriesCaptured = 0,
    this.isOnline = false,
    required this.joinedAt,
  });

  factory ClanMemberModel.fromJson(Map<String, dynamic> json) {
    return ClanMemberModel(
      userId: json['user_id'],
      clanId: json['clan_id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'prospect',
      kmRan: (json['km_ran'] ?? 0).toDouble(),
      territoriesCaptured: json['territories_captured'] ?? 0,
      isOnline: json['is_online'] ?? false,
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}

class ClanMessageModel {
  final String id;
  final String clanId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const ClanMessageModel({
    required this.id,
    required this.clanId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory ClanMessageModel.fromJson(Map<String, dynamic> json) {
    return ClanMessageModel(
      id: json['id'],
      clanId: json['clan_id'],
      userId: json['user_id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class JoinRequestModel {
  final String id;
  final String clanId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final double kmRan;
  final int territoriesCaptured;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  const JoinRequestModel({
    required this.id,
    required this.clanId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.kmRan = 0,
    this.territoriesCaptured = 0,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['id'],
      clanId: json['clan_id'],
      userId: json['user_id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      kmRan: (json['km_ran'] ?? 0).toDouble(),
      territoriesCaptured: json['territories_captured'] ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
