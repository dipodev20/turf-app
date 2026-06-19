import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/map/models/territory_model.dart';
import 'package:turf_app/core/constants/app_constants.dart';
import 'package:uuid/uuid.dart';

// ── KALMAN FILTER ──────────────────────────────────────────────
class KalmanFilter {
  double _lat, _lng, _variance;
  static const double _minAccuracy = 3.0;

  KalmanFilter(double lat, double lng, double accuracy)
      : _lat = lat, _lng = lng, _variance = accuracy * accuracy;

  LatLng update(double lat, double lng, double accuracy) {
    final q = max(accuracy * accuracy, _minAccuracy);
    _variance += q;
    final k = _variance / (_variance + q);
    _lat = _lat + k * (lat - _lat);
    _lng = _lng + k * (lng - _lng);
    _variance = (1 - k) * _variance;
    return LatLng(_lat, _lng);
  }

  LatLng get position => LatLng(_lat, _lng);
}

// ── CONVEX HULL (Graham scan) ──────────────────────────────────
List<LatLng> convexHull(List<LatLng> points) {
  if (points.length < 3) return points;
  
  // Find bottom-most point
  var pivot = points.reduce((a, b) => 
    a.latitude < b.latitude || (a.latitude == b.latitude && a.longitude < b.longitude) ? a : b);
  
  // Sort by polar angle
  final sorted = points.where((p) => p != pivot).toList()
    ..sort((a, b) {
      final angleA = atan2(a.latitude - pivot.latitude, a.longitude - pivot.longitude);
      final angleB = atan2(b.latitude - pivot.latitude, b.longitude - pivot.longitude);
      return angleA.compareTo(angleB);
    });
  
  // Graham scan
  final hull = <LatLng>[pivot];
  for (final p in sorted) {
    while (hull.length > 1) {
      final cross = (hull[hull.length-1].longitude - hull[hull.length-2].longitude) *
                    (p.latitude - hull[hull.length-2].latitude) -
                    (hull[hull.length-1].latitude - hull[hull.length-2].latitude) *
                    (p.longitude - hull[hull.length-2].longitude);
      if (cross <= 0) hull.removeLast();
      else break;
    }
    hull.add(p);
  }
  return hull;
}

// ── BUFFER POLYGON ─────────────────────────────────────────────
List<LatLng> buildBufferPolygon(List<LatLng> path, double radiusMeters) {
  if (path.length < 2) return [];
  final List<LatLng> left = [], right = [];
  final buf = radiusMeters / 111320;
  
  for (int i = 0; i < path.length; i++) {
    final p = path[i];
    double dLat, dLng;
    if (i < path.length - 1) {
      dLat = path[i + 1].latitude - p.latitude;
      dLng = path[i + 1].longitude - p.longitude;
    } else {
      dLat = p.latitude - path[i - 1].latitude;
      dLng = p.longitude - path[i - 1].longitude;
    }
    final len = sqrt(dLat * dLat + dLng * dLng);
    if (len == 0) continue;
    left.add(LatLng(p.latitude - dLng / len * buf, p.longitude + dLat / len * buf));
    right.add(LatLng(p.latitude + dLng / len * buf, p.longitude - dLat / len * buf));
  }
  return [...left, ...right.reversed];
}

// ── PROVIDERS ──────────────────────────────────────────────────
final currentPositionProvider = StreamProvider<Position?>((ref) async* {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) { yield null; return; }
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) { yield null; return; }
  }
  if (permission == LocationPermission.deniedForever) { yield null; return; }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    ),
  ).where((p) => p.accuracy <= 40.0);
});

enum SpeedStatus { walking, cycling, vehicle }
SpeedStatus getSpeedStatus(double kmh) {
  if (kmh <= maxWalkSpeed) return SpeedStatus.walking;
  if (kmh <= maxCycleSpeed) return SpeedStatus.cycling;
  return SpeedStatus.vehicle;
}

final territoriesProvider = StreamProvider<List<TerritoryModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.from("territories").stream(primaryKey: ["id"])
      .map((data) => data.map((e) => TerritoryModel.fromJson(e)).toList());
});

final livePlayersProvider = StreamProvider<List<LivePlayerModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final currentUser = supabase.auth.currentUser;
  return supabase.from("live_players").stream(primaryKey: ["user_id"]).map((data) => data
      .where((e) => e["user_id"] != currentUser?.id)
      .where((e) => DateTime.now().difference(DateTime.parse(e["updated_at"])).inMinutes < 5)
      .map((e) => LivePlayerModel.fromJson(e)).toList());
});

// Global Arena territories
final globalTerritoriesProvider = StreamProvider<List<TerritoryModel>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.from("territories").stream(primaryKey: ["id"])
      .map((data) => data.map((e) => TerritoryModel.fromJson(e)).toList());
});

// ── RUN STATE ──────────────────────────────────────────────────
class RunState {
  final bool isRunning;
  final List<LatLng> routePoints;
  final List<LatLng> polygonPoints;
  final double distanceKm;
  final int durationSeconds;
  final double currentSpeedKmh;
  final SpeedStatus speedStatus;
  final bool justCaptured;
  final LatLng? smoothedPosition;
  final double gpsAccuracy;      // For accuracy indicator

  const RunState({
    this.isRunning = false,
    this.routePoints = const [],
    this.polygonPoints = const [],
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.currentSpeedKmh = 0,
    this.speedStatus = SpeedStatus.walking,
    this.justCaptured = false,
    this.smoothedPosition,
    this.gpsAccuracy = 0,
  });

  RunState copyWith({
    bool? isRunning,
    List<LatLng>? routePoints,
    List<LatLng>? polygonPoints,
    double? distanceKm,
    int? durationSeconds,
    double? currentSpeedKmh,
    SpeedStatus? speedStatus,
    bool? justCaptured,
    LatLng? smoothedPosition,
    double? gpsAccuracy,
  }) {
    return RunState(
      isRunning: isRunning ?? this.isRunning,
      routePoints: routePoints ?? this.routePoints,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      speedStatus: speedStatus ?? this.speedStatus,
      justCaptured: justCaptured ?? this.justCaptured,
      smoothedPosition: smoothedPosition ?? this.smoothedPosition,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
    );
  }
}

// ── RUN NOTIFIER ───────────────────────────────────────────────
class RunNotifier extends Notifier<RunState> {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _timer;
  final _dist = const Distance();
  KalmanFilter? _kalman;
  Position? _lastPos;
  DateTime? _lastPosTime;
  
  // Sensor fusion
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  LatLng? _deadReckonPos;
  DateTime? _lastAccelTime;

  @override
  RunState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _accelSub?.cancel();
      _timer?.cancel();
    });
    return const RunState();
  }

  void startRun() {
    if (state.isRunning) return;
    _kalman = null;
    _lastPos = null;
    _lastPosTime = null;
    _deadReckonPos = null;

    state = state.copyWith(
      isRunning: true, routePoints: [], polygonPoints: [],
      distanceKm: 0, durationSeconds: 0, justCaptured: false,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) =>
        state = state.copyWith(durationSeconds: state.durationSeconds + 1));

    // Start accelerometer for sensor fusion
    _accelSub = accelerometerEventStream().listen((event) {
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
      _lastAccelTime = DateTime.now();
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      if (pos.accuracy > 50) return;

      // Anti-teleport
      if (_lastPos != null && _lastPosTime != null) {
        final elapsed = DateTime.now().difference(_lastPosTime!).inMilliseconds / 1000.0;
        if (elapsed > 0) {
          final d = _dist.as(LengthUnit.Meter,
              LatLng(_lastPos!.latitude, _lastPos!.longitude),
              LatLng(pos.latitude, pos.longitude));
          if (d / elapsed > 20) return;
        }
      }

      _lastPos = pos;
      _lastPosTime = DateTime.now();

      // Kalman filter
      LatLng smoothed;
      if (_kalman == null) {
        _kalman = KalmanFilter(pos.latitude, pos.longitude, pos.accuracy);
        smoothed = LatLng(pos.latitude, pos.longitude);
      } else {
        smoothed = _kalman!.update(pos.latitude, pos.longitude, pos.accuracy);
      }

      _onSmoothed(smoothed, pos.speed * 3.6, pos.accuracy);
    });
  }

  void _onSmoothed(LatLng smoothed, double speedKmh, double accuracy) {
    speedKmh = speedKmh.clamp(0.0, 50.0);
    final speedStatus = getSpeedStatus(speedKmh);
    final newPoints = [...state.routePoints, smoothed];

    double newDist = state.distanceKm;
    if (state.routePoints.isNotEmpty) {
      final seg = _dist.as(LengthUnit.Meter, state.routePoints.last, smoothed);
      if (seg < 50) newDist += seg / 1000;
    }

    // Buffer polygon for preview
    final poly = newPoints.length >= 3
        ? buildBufferPolygon(newPoints, 8.0)
        : state.polygonPoints;

    state = state.copyWith(
      routePoints: newPoints,
      polygonPoints: poly,
      distanceKm: newDist,
      currentSpeedKmh: speedKmh,
      speedStatus: speedStatus,
      smoothedPosition: smoothed,
      gpsAccuracy: accuracy,
    );

    _updateLive(smoothed, speedKmh);

    if (speedStatus != SpeedStatus.vehicle && newPoints.length >= 15 && newDist >= 0.15) {
      _checkCapture(newPoints, newDist);
    }
  }

  Future<void> _updateLive(LatLng pos, double speedKmh) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userData = ref.read(currentUserProvider).value;
    if (userData?.shareLocation != true) return;
    await supabase.from("live_players").upsert({
      "user_id": user.id, "username": userData?.username ?? "",
      "latitude": pos.latitude, "longitude": pos.longitude,
      "speed_kmh": speedKmh, "clan_id": userData?.clanId,
      "skin_id": userData?.skinId, "updated_at": DateTime.now().toIso8601String(),
    });
  }

  void _checkCapture(List<LatLng> points, double distKm) {
    final closingDist = _dist.as(LengthUnit.Meter, points.first, points.last);
    if (closingDist < 80 && distKm >= 0.15) {
      double maxD = 0;
      for (final p in points) {
        final d = _dist.as(LengthUnit.Meter, points.first, p);
        if (d > maxD) maxD = d;
      }
      if (maxD > 20) _captureTerritory(List.from(points));
    }
  }

  Future<void> _captureTerritory(List<LatLng> points) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userData = ref.read(currentUserProvider).value;
    if (userData?.clanId == null) return;

    final clan = await supabase.from("clans")
        .select("name,flag_url,color")
        .eq("id", userData!.clanId!).single();

    final result = await supabase.rpc("capture_territory", params: {
      "p_clan_id": userData.clanId,
      "p_clan_name": clan["name"],
      "p_clan_flag_url": clan["flag_url"] ?? "",
      "p_clan_color": clan["color"] ?? "#5B5BD6",
      "p_captured_by": user.id,
      "p_points": points.map((p) => [p.latitude, p.longitude]).toList(),
      "p_buffer_meters": 8.0,
    });

    if (result != null && result["success"] == true) {
      ref.invalidate(currentUserProvider);
      state = state.copyWith(routePoints: [], polygonPoints: [], justCaptured: true);
      Timer(const Duration(seconds: 3), () {
        if (state.isRunning) state = state.copyWith(justCaptured: false);
      });
    }
  }

  double _calcArea(List<LatLng> pts) {
    if (pts.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].latitude * pts[j].longitude - pts[j].latitude * pts[i].longitude;
    }
    return area.abs() / 2 * 111320 * 111320;
  }

  Future<void> stopRun() async {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _timer?.cancel();
    _positionSub = null;
    _accelSub = null;
    _timer = null;
    _kalman = null;

    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user != null && state.distanceKm > 0) {
      final cu = ref.read(currentUserProvider).value;
      await supabase.from("users").update(
          {"km_ran": (cu?.kmRan ?? 0) + state.distanceKm}).eq("id", user.id);
      await supabase.from("live_players").delete().eq("user_id", user.id);
      ref.invalidate(currentUserProvider);
    }
    state = const RunState();
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
