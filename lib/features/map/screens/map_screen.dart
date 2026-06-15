import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/constants/app_constants.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/map/providers/map_provider.dart';
import 'package:turf_app/features/map/models/territory_model.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _followUser = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final territoriesAsync = ref.watch(territoriesProvider);
    final livePlayersAsync = ref.watch(livePlayersProvider);
    final runState = ref.watch(runProvider);
    final myClan = ref.watch(myClanProvider).value;

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
              // Run route
              if (runState.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: runState.routePoints,
                      color: AppTheme.accent.withOpacity(0.85),
                      strokeWidth: 3.5,
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
              // My position
              positionAsync.when(
                data: (pos) {
                  if (pos == null) return const MarkerLayer(markers: []);
                  return MarkerLayer(markers: [
                    _buildMyMarker(LatLng(pos.latitude, pos.longitude)),
                  ]);
                },
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // ── TOP BAR ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16,
            child: _buildTopBar(),
          ),

          // ── SEASON BANNER ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 66,
            left: 16, right: 16,
            child: _buildSeasonBanner(myClan),
          ),

          // ── TERRITORY COUNTER (top left below season) ──
          if (!runState.isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 124,
              left: 16,
              child: _buildTerritoryCounter(),
            ),

          // ── RUNNING BANNER ──
          if (runState.isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 124,
              left: 16, right: 16,
              child: _buildRunningBanner(runState),
            ),
          // Capture notification placeholder
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF34C759), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 24),
                    const SizedBox(width: 10),
                    Text('Territory Captured!',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),

          // ── MAP CONTROLS ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.38,
            child: _buildMapControls(),
          ),

          // ── RECENTER BUTTON ──
          if (!_followUser)
            Positioned(
              right: 16,
              bottom: 110,
              child: GestureDetector(
                onTap: () {
                  setState(() => _followUser = true);
                  positionAsync.whenData((pos) {
                    if (pos != null) _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
                  });
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.my_location_rounded, color: AppTheme.accent, size: 22),
                ),
              ),
            ),

          // ── LEGEND ──
          Positioned(
            bottom: 82,
            left: 16,
            child: _buildLegend(),
          ),

          // ── START/STOP RUN BUTTON ──
          Positioned(
            bottom: 20,
            left: 20, right: 20,
            child: _buildRunButton(runState),
          ),
        ],
      ),
    );
  }

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
      color: color.withOpacity(0.22),
      borderColor: color.withOpacity(0.6),
      borderStrokeWidth: 1.5,
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
          boxShadow: [BoxShadow(color: AppTheme.red.withOpacity(0.4), blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            player.username.isNotEmpty ? player.username[0].toUpperCase() : '?',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Marker _buildMyMarker(LatLng point) {
    return Marker(
      point: point,
      width: 48, height: 48,
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
                  color: AppTheme.accent.withOpacity(0.15),
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
                boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.5), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search, color: AppTheme.t3, size: 18),
                const SizedBox(width: 8),
                Text('Search territories...', style: GoogleFonts.inter(color: AppTheme.t3, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _topBtn(Icons.notifications_outlined),
        const SizedBox(width: 8),
        _topBtn(Icons.wb_sunny_outlined),
      ],
    );
  }

  Widget _topBtn(IconData icon) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Icon(icon, color: AppTheme.t1, size: 20),
    );
  }

  Widget _buildSeasonBanner(dynamic myClan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.star_rounded, color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Season III · Active', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(myClan != null ? '${myClan.name} — #1 in ${myClan.city ?? "City"}' : 'Join a clan to start',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t3)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('12d', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
              Text('left', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.t3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryCounter() {
    final territoriesAsync = ref.watch(territoriesProvider);
    return territoriesAsync.when(
      data: (territories) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('My zones', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t3, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Text('${territories.length}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accent)),
              ],
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildRunningBanner(RunState runState) {
    final statusColor = runState.speedStatus == SpeedStatus.walking
        ? AppTheme.green
        : runState.speedStatus == SpeedStatus.cycling
            ? AppTheme.orange
            : AppTheme.red;
    final statusText = runState.speedStatus == SpeedStatus.walking
        ? '🚶 Walking'
        : runState.speedStatus == SpeedStatus.cycling
            ? '🚲 Cycling'
            : '🚗 Too fast!';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(statusText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
          const Spacer(),
          Text(
            '${runState.distanceKm.toStringAsFixed(2)} km',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
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

  Widget _buildMapControls() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
          ),
          child: Column(
            children: [
              _ctrlBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
              Divider(height: 1, color: AppTheme.sep),
              _ctrlBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
          ),
          child: const Icon(Icons.location_on_outlined, color: AppTheme.accent, size: 20),
        ),
      ],
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44, height: 44,
        child: Icon(icon, size: 20, color: AppTheme.t1),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(AppTheme.accent, 'My Clan'),
          const SizedBox(height: 5),
          _legendRow(AppTheme.red, 'Enemies'),
          const SizedBox(height: 5),
          _legendRow(AppTheme.t4, 'Neutral'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t2, fontWeight: FontWeight.w500)),
      ],
    );
  }

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
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: runState.isRunning
                ? [AppTheme.red, AppTheme.red.withOpacity(0.85)]
                : [AppTheme.accent, AppTheme.accent2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (runState.isRunning ? AppTheme.red : AppTheme.accent).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              runState.isRunning ? Icons.stop_rounded : Icons.directions_run_rounded,
              color: Colors.white, size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              runState.isRunning ? 'Stop Run' : 'Start Run',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
            ),
            if (!runState.isRunning) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${runState.distanceKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}
