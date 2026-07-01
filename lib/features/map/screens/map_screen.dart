import 'package:turf_app/features/notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/constants/app_constants.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/map/providers/map_provider.dart';
import 'package:turf_app/features/map/models/territory_model.dart';
import 'dart:ui' as ui;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _followUser = true;
  bool _showGlobalArena = false;
  LatLng? _animatedPosition;
  LatLng? _targetPosition;
  late AnimationController _pulseController;
  AnimationController? _moveController;
  Animation<double>? _moveAnimation;
  LatLng? _fromPosition;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _moveController?.dispose();
    super.dispose();
  }

  void _animateToPosition(LatLng newPos) {
    if (_animatedPosition == null) {
      setState(() => _animatedPosition = newPos);
      return;
    }
    _fromPosition = _animatedPosition;
    _targetPosition = newPos;
    _moveController?.reset();
    _moveAnimation = CurvedAnimation(
        parent: _moveController!, curve: Curves.easeInOut);
    _moveController?.addListener(() {
      if (_fromPosition == null || _targetPosition == null) return;
      final t = _moveAnimation!.value;
      setState(() {
        _animatedPosition = LatLng(
          _fromPosition!.latitude +
              (_targetPosition!.latitude - _fromPosition!.latitude) * t,
          _fromPosition!.longitude +
              (_targetPosition!.longitude - _fromPosition!.longitude) * t,
        );
      });
    });
    _moveController?.forward();
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final territoriesAsync = ref.watch(territoriesProvider);
    final livePlayersAsync = ref.watch(livePlayersProvider);
    final runState = ref.watch(runProvider);

    positionAsync.whenData((position) {
      if (position != null && _followUser) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(42.8746, 74.5698),
              initialZoom: 15,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) setState(() => _followUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrlTemplate,
                userAgentPackageName: 'com.example.turf_app',
              ),
              // Territory polygons
              territoriesAsync.when(
                data: (territories) => PolygonLayer<Object>(
                  polygons: territories.map((t) => _buildPolygon(t)).toList(),
                ),
                loading: () => const PolygonLayer<Object>(polygons: []),
                error: (_, __) => const PolygonLayer<Object>(polygons: []),
              ),
              // Preview polygon
              if (runState.polygonPoints.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: runState.polygonPoints,
                      color: AppTheme.accent.withValues(alpha: 0.22),
                      borderColor: AppTheme.accent.withValues(alpha: 0.7),
                      borderStrokeWidth: 2.0,
                      isFilled: true,
                    ),
                  ],
                ),
              // Run route line
              if (runState.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: runState.routePoints,
                      color: AppTheme.accent.withValues(alpha: 0.0),
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              // Live players
              livePlayersAsync.when(
                data: (players) => MarkerLayer(
                  markers: players.map((p) => _buildPlayerMarker(p)).toList(),
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),
              // GPS accuracy circle — небольшой декоративный индикатор
              if (runState.isRunning && _animatedPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _animatedPosition!,
                      radius: runState.gpsAccuracy.clamp(3.0, 15.0),
                      useRadiusInMeter: true,
                      color: _accuracyColor(runState.gpsAccuracy)
                          .withValues(alpha: 0.12),
                      borderColor: _accuracyColor(runState.gpsAccuracy)
                          .withValues(alpha: 0.4),
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                ),
              // My position
              Builder(builder: (context) {
                final smoothed = runState.smoothedPosition;
                final rawPos = positionAsync.value;
                LatLng? newPos;
                if (smoothed != null) {
                  newPos = smoothed;
                } else if (rawPos != null) {
                  newPos = LatLng(rawPos.latitude, rawPos.longitude);
                }
                if (newPos != null && newPos != _targetPosition) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _animateToPosition(newPos!);
                    if (_followUser) {
                      _mapController.move(newPos, _mapController.camera.zoom);
                    }
                  });
                }
                if (_animatedPosition == null) return const MarkerLayer(markers: []);
                return MarkerLayer(markers: [_buildMyMarker(_animatedPosition!)]);
              }),
            ],
          ),

          // ── TOP BAR ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16,
            child: _buildTopBar(),
          ),

          // ── RUNNING BANNER ──
          if (runState.isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 66,
              left: 16, right: 16,
              child: _buildRunningBanner(runState),
            ),

          // ── ARENA TOGGLE (только когда не бежим) ──
          if (!runState.isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 66,
              left: 16,
              child: _buildArenaToggle(),
            ),

          // ── MAP CONTROLS (zoom) ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.38,
            child: _buildZoomControls(),
          ),

          // ── RECENTER ──
          if (!_followUser)
            Positioned(
              right: 16, bottom: 110,
              child: GestureDetector(
                onTap: () {
                  setState(() => _followUser = true);
                  positionAsync.whenData((pos) {
                    if (pos != null) {
                      _mapController.move(
                          LatLng(pos.latitude, pos.longitude), 15);
                    }
                  });
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 12)],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),

          // ── LEGEND ──
          Positioned(
            bottom: 90, left: 16,
            child: _buildLegend(),
          ),

          // ── CAPTURED FLASH ──
          if (runState.justCaptured)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: runState.justCaptured ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.5),
                              blurRadius: 30)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text('Territory Captured!',
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── START/STOP BUTTON ──
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: _buildRunButton(runState),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        // Search field
        Expanded(
          child: GestureDetector(
            onTap: _showCitySearch,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, color: AppTheme.t3, size: 18),
                  const SizedBox(width: 8),
                  Text('Search city...',
                      style: GoogleFonts.inter(
                          color: AppTheme.t3, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Notifications
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          child: _topIconBtn(
            child: const Icon(Icons.notifications_outlined,
                color: AppTheme.t1, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // Follow location
        GestureDetector(
          onTap: () {
            setState(() => _followUser = true);
            final pos = ref.read(currentPositionProvider).value;
            if (pos != null) {
              _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
            }
          },
          child: _topIconBtn(
            active: _followUser,
            child: Icon(
              Icons.my_location_rounded,
              color: _followUser ? Colors.white : AppTheme.t1,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _showCitySearch() {
    final _searchController = TextEditingController();
    final List<Map<String, dynamic>> _cities = [
      {'name': 'Bishkek', 'lat': 42.8746, 'lng': 74.5698},
      {'name': 'Osh', 'lat': 40.5283, 'lng': 72.7985},
      {'name': 'Almaty', 'lat': 43.2220, 'lng': 76.8512},
      {'name': 'Tashkent', 'lat': 41.2995, 'lng': 69.2401},
      {'name': 'Moscow', 'lat': 55.7558, 'lng': 37.6173},
      {'name': 'Istanbul', 'lat': 41.0082, 'lng': 28.9784},
      {'name': 'Dubai', 'lat': 25.2048, 'lng': 55.2708},
      {'name': 'London', 'lat': 51.5074, 'lng': -0.1278},
      {'name': 'New York', 'lat': 40.7128, 'lng': -74.0060},
      {'name': 'Tokyo', 'lat': 35.6762, 'lng': 139.6503},
    ];
    List<Map<String, dynamic>> _filtered = List.from(_cities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: AppTheme.t4,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) {
                    setModalState(() {
                      _filtered = _cities
                          .where((c) => (c['name'] as String)
                              .toLowerCase()
                              .contains(v.toLowerCase()))
                          .toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search city...',
                    hintStyle: GoogleFonts.inter(color: AppTheme.t3),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.t3, size: 18),
                    filled: true,
                    fillColor: AppTheme.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final city = _filtered[i];
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_city_rounded,
                            color: AppTheme.accent, size: 18),
                      ),
                      title: Text(city['name'],
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        _mapController.move(
                          LatLng(city['lat'], city['lng']),
                          14.0,
                        );
                        setState(() => _followUser = false);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topIconBtn({
    VoidCallback? onTap,
    required Widget child,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
        ),
        child: Center(child: child),
      ),
    );
  }


  // ── ARENA TOGGLE ──────────────────────────────────────────────────────────
  Widget _buildArenaToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showGlobalArena = !_showGlobalArena),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _showGlobalArena ? AppTheme.accent : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CustomPaint(
                painter: _SvgIcon(
                  _showGlobalArena ? _MapIcons.globe : _MapIcons.city,
                  _showGlobalArena ? Colors.white : AppTheme.t1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _showGlobalArena ? 'Global Arena' : 'Local',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _showGlobalArena ? Colors.white : AppTheme.t1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RUNNING BANNER ────────────────────────────────────────────────────────
  Widget _buildRunningBanner(RunState runState) {
    final isWalking = runState.speedStatus == SpeedStatus.walking;
    final isCycling = runState.speedStatus == SpeedStatus.cycling;
    final statusColor = isWalking
        ? AppTheme.green
        : isCycling ? AppTheme.orange : AppTheme.red;
    final statusIcon = isWalking
        ? _MapIcons.walking
        : isCycling ? _MapIcons.cycling : _MapIcons.vehicle;
    final statusText = isWalking
        ? 'Walking'
        : isCycling ? 'Cycling' : 'Too fast!';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 14, height: 14,
            child: CustomPaint(
                painter: _SvgIcon(statusIcon, statusColor)),
          ),
          const SizedBox(width: 5),
          Text(statusText,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor)),
          const Spacer(),
          Text(
            '${runState.distanceKm.toStringAsFixed(2)} km',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(runState.durationSeconds),
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.t3),
          ),
        ],
      ),
    );
  }

  // ── ZOOM CONTROLS ─────────────────────────────────────────────────────────
  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Column(
        children: [
          _zoomBtn(Icons.add_rounded,
              () => _mapController.move(_mapController.camera.center,
                  _mapController.camera.zoom + 1)),
          Divider(height: 1, color: AppTheme.sep),
          _zoomBtn(Icons.remove_rounded,
              () => _mapController.move(_mapController.camera.center,
                  _mapController.camera.zoom - 1)),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44, height: 44,
        child: Icon(icon, size: 20, color: AppTheme.t1),
      ),
    );
  }

  // ── LEGEND ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(AppTheme.accent, 'My Clan'),
          const SizedBox(height: 4),
          _legendRow(AppTheme.red, 'Enemies'),
          const SizedBox(height: 4),
          _legendRow(AppTheme.t4, 'Neutral'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 11, height: 11,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.t2,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── RUN BUTTON ────────────────────────────────────────────────────────────
  Widget _buildRunButton(RunState runState) {
    return GestureDetector(
      onTap: () {
        if (runState.isRunning) {
          ref.read(runProvider.notifier).stopRun();
        } else {
          ref.read(runProvider.notifier).startRun();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: runState.isRunning
                ? [const Color(0xFFFF3B30), const Color(0xFFFF6B6B)]
                : [AppTheme.accent, AppTheme.accent2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (runState.isRunning ? AppTheme.red : AppTheme.accent)
                  .withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22, height: 22,
              child: CustomPaint(
                painter: _SvgIcon(
                  runState.isRunning ? _MapIcons.stop : _MapIcons.run,
                  Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              runState.isRunning ? 'Stop Run' : 'Start Run',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3),
            ),
            if (runState.isRunning) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(runState.durationSeconds),
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── MARKERS ───────────────────────────────────────────────────────────────
  Polygon _buildPolygon(TerritoryModel territory) {
    Color color;
    try {
      final hex = territory.clanColor.replaceAll('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      color = AppTheme.accent;
    }
    return Polygon(
      points: territory.points,
      color: color.withValues(alpha: 0.22),
      borderColor: color.withValues(alpha: 0.6),
      borderStrokeWidth: 1.5,
      isFilled: true,
    );
  }

  Marker _buildPlayerMarker(LivePlayerModel player) {
    return Marker(
      point: player.latLng,
      width: 40, height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(
              color: AppTheme.red.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            player.username.isNotEmpty
                ? player.username[0].toUpperCase()
                : '?',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
        ),
      ),
    );
  }

  Marker _buildMyMarker(LatLng point) {
    return Marker(
      point: point,
      width: 52, height: 52,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.5),
                    blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy <= 10) return const Color(0xFF34C759);
    if (accuracy <= 20) return const Color(0xFFFFCC00);
    return const Color(0xFFFF3B30);
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

// ── SVG ИКОНКИ ────────────────────────────────────────────────────────────────
class _MapIcons {
  static const run = 'run';
  static const stop = 'stop';
  static const location = 'location';
  static const locationFilled = 'locationFilled';
  static const globe = 'globe';
  static const city = 'city';
  static const season = 'season';
  static const walking = 'walking';
  static const cycling = 'cycling';
  static const vehicle = 'vehicle';
}

class _SvgIcon extends CustomPainter {
  final String icon;
  final Color color;
  const _SvgIcon(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pf = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    switch (icon) {
      case 'run':
        // Бегущий человек
        canvas.drawCircle(Offset(s * 0.62, s * 0.12), s * 0.1, pf);
        final body = ui.Path()
          ..moveTo(s * 0.62, s * 0.22)
          ..lineTo(s * 0.5, s * 0.55)
          ..lineTo(s * 0.3, s * 0.75);
        canvas.drawPath(body, p);
        final arm = ui.Path()
          ..moveTo(s * 0.35, s * 0.38)
          ..lineTo(s * 0.65, s * 0.48)
          ..lineTo(s * 0.8, s * 0.38);
        canvas.drawPath(arm, p);
        final leg2 = ui.Path()
          ..moveTo(s * 0.5, s * 0.55)
          ..lineTo(s * 0.72, s * 0.72)
          ..lineTo(s * 0.65, s * 0.9);
        canvas.drawPath(leg2, p);
        break;

      case 'stop':
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.2, s * 0.2, s * 0.6, s * 0.6),
          Radius.circular(s * 0.12),
        );
        canvas.drawRRect(rr, pf);
        break;

      case 'location':
        final pin = ui.Path()
          ..moveTo(s * 0.5, s * 0.95)
          ..cubicTo(s * 0.5, s * 0.95, s * 0.1, s * 0.55, s * 0.1, s * 0.38)
          ..arcTo(Rect.fromLTWH(s * 0.1, s * 0.05, s * 0.8, s * 0.66),
              3.14, 3.14, false)
          ..cubicTo(s * 0.9, s * 0.55, s * 0.5, s * 0.95, s * 0.5, s * 0.95)
          ..close();
        canvas.drawPath(pin, p);
        canvas.drawCircle(Offset(s * 0.5, s * 0.38), s * 0.14, p);
        break;

      case 'locationFilled':
        final pin = ui.Path()
          ..moveTo(s * 0.5, s * 0.95)
          ..cubicTo(s * 0.5, s * 0.95, s * 0.1, s * 0.55, s * 0.1, s * 0.38)
          ..arcTo(Rect.fromLTWH(s * 0.1, s * 0.05, s * 0.8, s * 0.66),
              3.14, 3.14, false)
          ..cubicTo(s * 0.9, s * 0.55, s * 0.5, s * 0.95, s * 0.5, s * 0.95)
          ..close();
        canvas.drawPath(pin, pf);
        canvas.drawCircle(Offset(s * 0.5, s * 0.38), s * 0.14,
            Paint()..color = Colors.white..style = PaintingStyle.fill);
        break;

      case 'globe':
        canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.42, p);
        canvas.drawLine(Offset(s * 0.08, s * 0.5), Offset(s * 0.92, s * 0.5), p);
        final oval = ui.Path()
          ..addOval(Rect.fromLTWH(s * 0.22, s * 0.08, s * 0.56, s * 0.84));
        canvas.drawPath(oval, p);
        break;

      case 'city':
        final city = ui.Path()
          ..moveTo(s * 0.1, s * 0.9)
          ..lineTo(s * 0.1, s * 0.45)
          ..lineTo(s * 0.38, s * 0.45)
          ..lineTo(s * 0.38, s * 0.2)
          ..lineTo(s * 0.62, s * 0.2)
          ..lineTo(s * 0.62, s * 0.45)
          ..lineTo(s * 0.9, s * 0.45)
          ..lineTo(s * 0.9, s * 0.9)
          ..close();
        canvas.drawPath(city, p);
        // Windows
        for (final x in [0.18, 0.28]) {
          canvas.drawRect(
              Rect.fromLTWH(s * x, s * 0.55, s * 0.08, s * 0.1), pf);
          canvas.drawRect(
              Rect.fromLTWH(s * x, s * 0.72, s * 0.08, s * 0.1), pf);
        }
        canvas.drawRect(
            Rect.fromLTWH(s * 0.46, s * 0.3, s * 0.08, s * 0.08), pf);
        break;

      case 'season':
        // Star
        final starPath = ui.Path();
        for (int i = 0; i < 5; i++) {
          final outerAngle = (i * 4 * 3.14159 / 5) - 3.14159 / 2;
          final innerAngle = outerAngle + 2 * 3.14159 / 5;
          final ox = s * 0.5 + s * 0.42 * cos(outerAngle);
          final oy = s * 0.5 + s * 0.42 * sin(outerAngle);
          final ix = s * 0.5 + s * 0.18 * cos(innerAngle);
          final iy = s * 0.5 + s * 0.18 * sin(innerAngle);
          if (i == 0) starPath.moveTo(ox, oy);
          else starPath.lineTo(ox, oy);
          starPath.lineTo(ix, iy);
        }
        starPath.close();
        canvas.drawPath(starPath, pf);
        break;

      case 'walking':
        canvas.drawCircle(Offset(s * 0.55, s * 0.1), s * 0.1, pf);
        final wb = ui.Path()
          ..moveTo(s * 0.55, s * 0.2)
          ..lineTo(s * 0.5, s * 0.55)
          ..lineTo(s * 0.3, s * 0.85);
        canvas.drawPath(wb, p);
        final wl2 = ui.Path()
          ..moveTo(s * 0.5, s * 0.55)
          ..lineTo(s * 0.68, s * 0.78)
          ..lineTo(s * 0.75, s * 0.9);
        canvas.drawPath(wl2, p);
        final wa = ui.Path()
          ..moveTo(s * 0.3, s * 0.35)
          ..lineTo(s * 0.7, s * 0.42);
        canvas.drawPath(wa, p);
        break;

      case 'cycling':
        canvas.drawCircle(Offset(s * 0.25, s * 0.7), s * 0.22, p);
        canvas.drawCircle(Offset(s * 0.75, s * 0.7), s * 0.22, p);
        final frame = ui.Path()
          ..moveTo(s * 0.25, s * 0.7)
          ..lineTo(s * 0.5, s * 0.35)
          ..lineTo(s * 0.75, s * 0.7)
          ..lineTo(s * 0.5, s * 0.7)
          ..lineTo(s * 0.25, s * 0.7);
        canvas.drawPath(frame, p);
        canvas.drawCircle(Offset(s * 0.6, s * 0.2), s * 0.1, pf);
        break;

      case 'vehicle':
        final car = ui.Path()
          ..moveTo(s * 0.1, s * 0.65)
          ..lineTo(s * 0.15, s * 0.45)
          ..lineTo(s * 0.35, s * 0.28)
          ..lineTo(s * 0.65, s * 0.28)
          ..lineTo(s * 0.85, s * 0.45)
          ..lineTo(s * 0.9, s * 0.65)
          ..close();
        canvas.drawPath(car, p);
        canvas.drawCircle(Offset(s * 0.28, s * 0.72), s * 0.12, p);
        canvas.drawCircle(Offset(s * 0.72, s * 0.72), s * 0.12, p);
        break;
    }
  }

  double cos(double x) => _cos(x);
  double sin(double x) => _sin(x);

  double _cos(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / (2 * i * (2 * i - 1));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_SvgIcon old) => old.icon != icon || old.color != color;
}
