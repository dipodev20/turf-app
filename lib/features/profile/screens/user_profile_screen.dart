import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/models/user_model.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(userId));
    return userAsync.when(
      data: (user) => user == null
          ? Scaffold(
              backgroundColor: AppTheme.bg,
              appBar: AppBar(backgroundColor: AppTheme.white),
              body: const Center(child: Text('User not found')),
            )
          : _UserProfileBody(user: user),
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _UserProfileBody extends StatelessWidget {
  final UserModel user;
  const _UserProfileBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover
                      Container(
                        height: 140,
                        width: double.infinity,
                        color: const Color(0xFF1C1C1E),
                        child: user.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user.coverUrl!, fit: BoxFit.cover)
                            : Stack(children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                      painter: _GridPainter()),
                                ),
                              ]),
                      ),
                      // Back button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      // Avatar
                      Positioned(
                        bottom: -44, left: 16,
                        child: Stack(
                          children: [
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 16)
                                ],
                              ),
                              child: ClipOval(
                                child: user.avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: user.avatarUrl!,
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: AppTheme.t1,
                                        child: Center(
                                          child: Text(
                                            user.username.isNotEmpty
                                                ? user.username[0].toUpperCase()
                                                : '?',
                                            style: GoogleFonts.inter(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // Online dot
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: user.isOnline
                                      ? AppTheme.green
                                      : AppTheme.t4,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.white, width: 2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),

                  // Info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(user.username,
                                          style: GoogleFonts.inter(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5)),
                                      const SizedBox(width: 7),
                                      Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                            color: AppTheme.accent,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.check,
                                            size: 12, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Online статус / last seen
                                  Row(
                                    children: [
                                      Container(
                                        width: 7, height: 7,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          color: user.isOnline
                                              ? AppTheme.green
                                              : AppTheme.t4,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        user.lastSeenText,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: user.isOnline
                                                ? AppTheme.green
                                                : AppTheme.t3),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(user.bio!,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.t2,
                                  height: 1.45)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (user.city != null)
                              _MetaPill(Icons.location_on_outlined, user.city!),
                            _MetaPill(Icons.calendar_today_outlined,
                                'Since ${user.createdAt.year}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── STATS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATS',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppTheme.t3)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                              icon: Icons.map_outlined,
                              value: '${user.territoriesCaptured}',
                              label: 'Territories',
                              color: AppTheme.accent)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.directions_run_rounded,
                              value: user.kmRan.toStringAsFixed(1),
                              label: 'KM Ran',
                              color: AppTheme.blue)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.local_fire_department_rounded,
                              value: '${user.currentStreak}',
                              label: 'Streak',
                              color: AppTheme.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                              icon: Icons.shield_rounded,
                              value: '${user.territoriesDefended}',
                              label: 'Defenses',
                              color: AppTheme.orange)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.emoji_events_rounded,
                              value: 'Lv.${user.level}',
                              label: 'Level',
                              color: AppTheme.gold)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatCard(
                              icon: Icons.star_rounded,
                              value: '${user.maxStreak}d',
                              label: 'Best Streak',
                              color: AppTheme.purple)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.t3)),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sep),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.t3),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.t3,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
