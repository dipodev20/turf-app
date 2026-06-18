import 'package:latlong2/latlong.dart';

class TerritoryModel {
  final String id;
  final String clanId;
  final String clanName;
  final String? clanFlagUrl;
  final String clanColor;
  final List<LatLng> points;
  final double areaSqMeters;
  final DateTime capturedAt;
  final String capturedBy;
  final bool isGlobal;
  final List<LatLng> virtualPoints;

  const TerritoryModel({
    required this.id,
    required this.clanId,
    required this.clanName,
    this.clanFlagUrl,
    required this.clanColor,
    required this.points,
    required this.areaSqMeters,
    required this.capturedAt,
    required this.capturedBy,
    this.isGlobal = false,
    this.virtualPoints = const [],
  });

  factory TerritoryModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List;
    final points = rawPoints.map((p) {
      final coords = p as List;
      return LatLng(coords[0].toDouble(), coords[1].toDouble());
    }).toList();

    return TerritoryModel(
      id: json['id'],
      clanId: json['clan_id'],
      clanName: json['clan_name'] ?? '',
      clanFlagUrl: json['clan_flag_url'],
      clanColor: json['clan_color'] ?? '#5B5BD6',
      points: points,
      areaSqMeters: (json['area_sq_meters'] ?? 0).toDouble(),
      capturedAt: DateTime.parse(json['captured_at']),
      capturedBy: json['captured_by'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clan_id': clanId,
    'clan_name': clanName,
    'clan_flag_url': clanFlagUrl,
    'clan_color': clanColor,
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'area_sq_meters': areaSqMeters,
    'captured_at': capturedAt.toIso8601String(),
    'captured_by': capturedBy,
  };
}

class LivePlayerModel {
  final String userId;
  final String username;
  final String? skinId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final String? clanId;
  final String? clanColor;
  final DateTime updatedAt;

  const LivePlayerModel({
    required this.userId,
    required this.username,
    this.skinId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    this.clanId,
    this.clanColor,
    required this.updatedAt,
  });

  factory LivePlayerModel.fromJson(Map<String, dynamic> json) {
    return LivePlayerModel(
      userId: json['user_id'],
      username: json['username'] ?? '',
      skinId: json['skin_id'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      speedKmh: (json['speed_kmh'] ?? 0).toDouble(),
      clanId: json['clan_id'],
      clanColor: json['clan_color'],
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  LatLng get latLng => LatLng(latitude, longitude);
}
