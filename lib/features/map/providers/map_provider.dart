import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/map/models/territory_model.dart';
import 'package:turf_app/core/constants/app_constants.dart';

// ── KALMAN FILTER ──────────────────────────────────────────────
class KalmanFilter {
  double _lat, _lng, _variance;
  static const double _minAccuracy = 3.0;
  static const double _maxVariance = 100.0;
  double _lastSpeed = 0;

  KalmanFilter(double lat, double lng, double accuracy)
      : _lat = lat, _lng = lng, _variance = accuracy * accuracy;

  LatLng update(double lat, double lng, double accuracy, double speedMs) {
    final q = max(accuracy * accuracy, _minAccuracy);
    
    // Адаптивный process noise в зависимости от скорости
    double processNoise;
    if (speedMs < 1.0) {
      processNoise = q * 0.3; // Меньше шума при медленном движении
    } else if (speedMs < 3.0) {
      processNoise = q * 0.6; // Средний шум для ходьбы
    } else {
      processNoise = q * 1.5; // Больше шума для бега/велосипеда
    }
    
    _variance = min(_variance + processNoise, _maxVariance);
    final k = _variance / (_variance + q);
    _lat = _lat + k * (lat - _lat);
    _lng = _lng + k * (lng - _lng);
    _variance = (1 - k) * _variance;
    _lastSpeed = speedMs;
    return LatLng(_lat, _lng);
  }

  LatLng get position => LatLng(_lat, _lng);
  double get lastSpeed => _lastSpeed;
}

// ── STATIONARY DETECTOR (accelerometer) ─────────────────────────
class StationaryDetector {
  final List<double> _buffer = [];
  static const int _bufferSize = 20; // Уменьшено для быстрой реакции
  static const double _varianceThreshold = 0.05; // Уменьшено для медленной ходьбы
  static const double _walkingVariance = 0.12; // Типичная вариативность при ходьбе
  int _consecutiveStationary = 0;
  static const int _requiredStationary = 5; // Нужно 5 последовательных "стопов"

  void addSample(double x, double y, double z) {
    final magnitude = sqrt(x * x + y * y + z * z) - 9.81;
    _buffer.add(magnitude.abs()); // Используем абсолютное значение
    if (_buffer.length > _bufferSize) _buffer.removeAt(0);
  }

  bool get isStationary {
    if (_buffer.length < _bufferSize) return false;
    final mean = _buffer.reduce((a, b) => a + b) / _buffer.length;
    final variance = _buffer.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / _buffer.length;
    
    bool currentlyStationary = variance < _varianceThreshold && mean < _walkingVariance;
    
    if (currentlyStationary) {
      _consecutiveStationary++;
    } else {
      _consecutiveStationary = 0;
    }
    
    return _consecutiveStationary >= _requiredStationary;
  }
}

// ── CONVEX HULL (Graham scan) ──────────────────────────────────
List<LatLng> convexHull(List<LatLng> points) {
  if (points.length < 3) return points;

  var pivot = points.reduce((a, b) =>
    a.latitude < b.latitude || (a.latitude == b.latitude && a.longitude < b.longitude) ? a : b);

  final sorted = points.where((p) => p != pivot).toList()
    ..sort((a, b) {
      final angleA = atan2(a.latitude - pivot.latitude, a.longitude - pivot.longitude);
      final angleB = atan2(b.latitude - pivot.latitude, b.longitude - pivot.longitude);
      return angleA.compareTo(angleB);
    });

  final hull = <LatLng>[pivot];
  for (final p in sorted) {
    while (hull.length > 1) {
      final cross = (hull[hull.length-1].longitude - hull[hull.length-2].longitude) *
                    (p.latitude - hull[hull.length-2].latitude) -
                    (hull[hull.length-1].latitude - hull[hull.length-2].latitude) *
                    (p.longitude - hull[hull.length-2].longitude);
      if (cross <= 0) {
        hull.removeLast();
      } else {
        break;
      }
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
  final double gpsAccuracy;
  final bool isStationary;

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
    this.isStationary = false,
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
    bool? isStationary,
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
      isStationary: isStationary ?? this.isStationary,
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
  double _lastSpeed = 0;
  final _stationaryDetector = StationaryDetector();

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

    state = state.copyWith(
      isRunning: true, routePoints: [], polygonPoints: [],
      distanceKm: 0, durationSeconds: 0, justCaptured: false,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) =>
        state = state.copyWith(durationSeconds: state.durationSeconds + 1));

    _accelSub = accelerometerEventStream().listen((event) {
      _stationaryDetector.addSample(event.x, event.y, event.z);
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      if (pos.accuracy > 22) return;

      final stationary = _stationaryDetector.isStationary;
      if (stationary) {
        state = state.copyWith(isStationary: true, gpsAccuracy: pos.accuracy);
        return;
      }
      if (state.isStationary) {
        state = state.copyWith(isStationary: false);
      }

      if (_lastPos != null && _lastPosTime != null) {
        final elapsed = DateTime.now().difference(_lastPosTime!).inMilliseconds / 1000.0;
        if (elapsed > 0) {
          final d = _dist.as(LengthUnit.Meter,
              LatLng(_lastPos!.latitude, _lastPos!.longitude),
              LatLng(pos.latitude, pos.longitude));
          
          // Защита от телепорта: скорость > 20 м/с (72 км/ч) — явный выброс
          if (d / elapsed > 20) return;
          
          // Фильтр для медленного движения: 
          // разрешаем точки с интервалом > 2 секунд или расстоянием > 1 метра
          if (d < 1.0 && elapsed < 2.0) return;
          
          // Проверка на реалистичность: ускорение не должно превышать 10 м/с²
          if (_lastSpeed > 0) {
            final acceleration = (d / elapsed - _lastSpeed) / elapsed;
            if (acceleration.abs() > 10) return;
          }
          _lastSpeed = d / elapsed;
        }
      }

      _lastPos = pos;
      _lastPosTime = DateTime.now();

      LatLng smoothed;
      if (_kalman == null) {
        _kalman = KalmanFilter(pos.latitude, pos.longitude, pos.accuracy);
        smoothed = LatLng(pos.latitude, pos.longitude);
      } else {
        smoothed = _kalman!.update(pos.latitude, pos.longitude, pos.accuracy, pos.speed);
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

    List<LatLng> poly;
    if (newPoints.length >= 3) {
      final closingDist = newPoints.length > 10
          ? _dist.as(LengthUnit.Meter, newPoints.first, smoothed)
          : double.infinity;
      
      // Проверяем замыкание: расстояние до старта < 40 метров
      // и достаточно точек для формирования полигона
      if (closingDist < 40 && newPoints.length >= 15 && newDist >= 0.1) {
        // Замыкаем круг, добавляя первую точку в конец если нужно
        final closedPoints = List<LatLng>.from(newPoints);
        if (closingDist > 5) {
          closedPoints.add(closedPoints.first); // Замыкаем кольцо
        }
        
        // Фильтруем дубликаты и почти дубликаты
        final filteredPoints = _filterClosePoints(closedPoints, 3.0); // мин. расстояние 3м
        
        if (filteredPoints.length >= 4) {
          final hull = convexHull(filteredPoints);
          poly = hull.length >= 4 ? hull : filteredPoints;
        } else {
          poly = buildBufferPolygon(filteredPoints, 10.0);
        }
      } else {
        // Для незамкнутого трека используем буфер большего размера
        poly = buildBufferPolygon(newPoints, 10.0);
      }
    } else {
      poly = state.polygonPoints;
    }

    state = state.copyWith(
      routePoints: newPoints,
      polygonPoints: poly,
      distanceKm: newDist,
      currentSpeedKmh: speedKmh,
      speedStatus: speedStatus,
      smoothedPosition: smoothed,
      gpsAccuracy: accuracy,
      isStationary: false,
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

  // Фильтрация точек, которые слишком близко друг к другу
  List<LatLng> _filterClosePoints(List<LatLng> points, double minDistanceM) {
    if (points.length < 2) return points;
    
    final filtered = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      final d = _dist.as(LengthUnit.Meter, filtered.last, points[i]);
      if (d >= minDistanceM) {
        filtered.add(points[i]);
      }
    }
    
    // Проверяем расстояние между последней и первой точкой
    if (filtered.length > 2) {
      final d = _dist.as(LengthUnit.Meter, filtered.last, filtered.first);
      if (d < minDistanceM && filtered.length > 3) {
        filtered.removeLast();
      }
    }
    
    return filtered;
  }

  void _checkCapture(List<LatLng> points, double distKm) {
    if (points.length < 15) return;

    final closingDist = _dist.as(LengthUnit.Meter, points.first, points.last);

    if (closingDist > 25 || distKm < 0.15) return;

    double maxD = 0;
    for (final p in points) {
      final d = _dist.as(LengthUnit.Meter, points.first, p);
      if (d > maxD) maxD = d;
    }
    if (maxD < 30) return;

    final area = _calcArea(points);
    if (area < 200) return;

    final hull = convexHull(List.from(points));
    if (hull.length < 3) return;

    _captureTerritory(hull);
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
