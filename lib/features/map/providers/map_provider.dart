import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/map/models/territory_model.dart';
import 'package:turf_app/core/constants/app_constants.dart';
import 'package:uuid/uuid.dart';

// Current position
final currentPositionProvider = StreamProvider<Position?>((ref) async* {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    yield null;
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      yield null;
      return;
    }
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  ).map((p) => p);
});

// Speed status
enum SpeedStatus { walking, cycling, vehicle }

SpeedStatus getSpeedStatus(double kmh) {
  if (kmh <= maxWalkSpeed) return SpeedStatus.walking;
  if (kmh <= maxCycleSpeed) return SpeedStatus.cycling;
  return SpeedStatus.vehicle;
}

// Territories
final territoriesProvider = StreamProvider<List<TerritoryModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);

  return supabase
      .from('territories')
      .stream(primaryKey: ['id'])
      .map((data) => data.map((e) => TerritoryModel.fromJson(e)).toList());
});

// Live players
final livePlayersProvider = StreamProvider<List<LivePlayerModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final currentUser = supabase.auth.currentUser;

  return supabase
      .from('live_players')
      .stream(primaryKey: ['user_id'])
      .map((data) => data
          .where((e) => e['user_id'] != currentUser?.id)
          .where((e) {
            final updated = DateTime.parse(e['updated_at']);
            return DateTime.now().difference(updated).inMinutes < 5;
          })
          .map((e) => LivePlayerModel.fromJson(e))
          .toList());
});

// Run session state
class RunState {
  final bool isRunning;
  final List<LatLng> routePoints;
  final double distanceKm;
  final int durationSeconds;
  final double currentSpeedKmh;
  final SpeedStatus speedStatus;

  const RunState({
    this.isRunning = false,
    this.routePoints = const [],
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.currentSpeedKmh = 0,
    this.speedStatus = SpeedStatus.walking,
  });

  RunState copyWith({
    bool? isRunning,
    List<LatLng>? routePoints,
    double? distanceKm,
    int? durationSeconds,
    double? currentSpeedKmh,
    SpeedStatus? speedStatus,
  }) {
    return RunState(
      isRunning: isRunning ?? this.isRunning,
      routePoints: routePoints ?? this.routePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      speedStatus: speedStatus ?? this.speedStatus,
    );
  }
}

class RunNotifier extends Notifier<RunState> {
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  final _distanceCalc = const Distance();

  @override
  RunState build() => const RunState();

  void startRun() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, routePoints: [], distanceKm: 0, durationSeconds: 0);

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });

    // GPS tracking
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((position) {
      _onPositionUpdate(position);
    });
  }

  void _onPositionUpdate(Position position) {
    final newPoint = LatLng(position.latitude, position.longitude);
    final speedKmh = position.speed * 3.6;
    final speedStatus = getSpeedStatus(speedKmh);

    final newPoints = [...state.routePoints, newPoint];

    // Calculate distance
    double newDistance = state.distanceKm;
    if (state.routePoints.isNotEmpty) {
      final lastPoint = state.routePoints.last;
      final segmentMeters = _distanceCalc.as(LengthUnit.Meter, lastPoint, newPoint);
      newDistance += segmentMeters / 1000;
    }

    state = state.copyWith(
      routePoints: newPoints,
      distanceKm: newDistance,
      currentSpeedKmh: speedKmh,
      speedStatus: speedStatus,
    );

    // Update live position in Supabase
    _updateLivePosition(position, speedKmh);

    // Check if territory can be captured
    if (speedStatus != SpeedStatus.vehicle) {
      _checkCapture(newPoints);
    }
  }

  Future<void> _updateLivePosition(Position position, double speedKmh) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final userData = ref.read(currentUserProvider).value;
    if (userData?.shareLocation != true) return;

    await supabase.from('live_players').upsert({
      'user_id': user.id,
      'username': userData?.username ?? '',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed_kmh': speedKmh,
      'clan_id': userData?.clanId,
      'skin_id': userData?.skinId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void _checkCapture(List<LatLng> points) {
    if (points.length < minPointsForCapture) return;

    // Check if route forms a closed polygon (start and end close enough)
    final first = points.first;
    final last = points.last;
    final dist = _distanceCalc.as(LengthUnit.Meter, first, last);

    if (dist < captureRadiusMeters) {
      _captureTerritory(points);
    }
  }

  Future<void> _captureTerritory(List<LatLng> points) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final userData = ref.read(currentUserProvider).value;
    if (userData?.clanId == null) return;

    // Get clan info
    final clanData = await supabase
        .from('clans')
        .select('name, flag_url, color')
        .eq('id', userData!.clanId!)
        .single();

    // Save territory
    await supabase.from('territories').insert({
      'id': const Uuid().v4(),
      'clan_id': userData.clanId,
      'clan_name': clanData['name'],
      'clan_flag_url': clanData['flag_url'],
      'clan_color': clanData['color'] ?? '#5B5BD6',
      'points': points.map((p) => [p.latitude, p.longitude]).toList(),
      'area_sq_meters': _calculateArea(points),
      'captured_at': DateTime.now().toIso8601String(),
      'captured_by': user.id,
    });

    // Update user stats
    await supabase.from('users').update({
      'territories_captured': (userData.territoriesCaptured + 1),
    }).eq('id', user.id);

    // Reset route after capture
    state = state.copyWith(routePoints: []);
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].latitude * points[j].longitude;
      area -= points[j].latitude * points[i].longitude;
    }
    return (area.abs() / 2) * 111320 * 111320;
  }

  Future<void> stopRun() async {
    _positionSub?.cancel();
    _timer?.cancel();

    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;

    if (user != null && state.distanceKm > 0) {
      final currentKm = ref.read(currentUserProvider).value?.kmRan ?? 0;
      await supabase.from('users').update({
        'km_ran': currentKm + state.distanceKm,
      }).eq('id', user.id);

      // Remove from live players
      await supabase.from('live_players').delete().eq('user_id', user.id);
    }

    state = const RunState();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
