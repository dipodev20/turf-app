import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/auth/models/user_model.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) => user == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _ProfileBody(user: user),
      loading: () => const Scaffold(backgroundColor: AppTheme.bg, body: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final UserModel user;
  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myClan = ref.watch(myClanProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // ── HERO ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              child: Column(
                children: [
                  // Cover + Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover
                      GestureDetector(
                        onTap: () => context.push('/profile/edit'),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          color: const Color(0xFF1C1C1E),
                          child: user.coverUrl != null
                              ? CachedNetworkImage(imageUrl: user.coverUrl!, fit: BoxFit.cover)
                              : Stack(
                                  children: [
                                    // Grid overlay like our HTML
                                    Positioned.fill(
                                      child: CustomPaint(painter: _GridPainter()),
                                    ),
                                    Center(
                                      child: Icon(Icons.add_photo_alternate_outlined,
                                          color: Colors.white.withOpacity(0.15), size: 36),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      // Edit cover btn
                      Positioned(
                        bottom: 10, right: 12,
                        child: GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      // Avatar
                      Positioned(
                        bottom: -44,
                        left: 16,
                        child: Stack(
                          children: [
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.white, width: 4),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16)],
                              ),
                              child: ClipOval(
                                child: user.avatarUrl != null
                                    ? CachedNetworkImage(imageUrl: user.avatarUrl!, fit: BoxFit.cover)
                                    : Container(
                                        color: AppTheme.t1,
                                        child: Center(
                                          child: Text(
                                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                            style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: user.isActuallyOnline ? AppTheme.green : AppTheme.t4,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.white, width: 2.5),
                                  boxShadow: user.isActuallyOnline ? [BoxShadow(color: AppTheme.green.withOpacity(0.4), blurRadius: 6)] : [],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),

                  // Buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _OutlineBtn(label: 'Share', icon: Icons.ios_share_outlined, onTap: () => Share.share('Check out my TURF profile! @${user.username} - ${user.territoriesCaptured} territories captured 🗺️')),
                        const SizedBox(width: 10),
                        _FilledBtn(label: 'Edit Profile', icon: Icons.edit_outlined, onTap: () => context.push('/profile/edit')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name + info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user.username,
                                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            const SizedBox(width: 7),
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 13, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('@${user.username.toLowerCase()} · Level ${user.level}',
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.t3)),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(user.bio!, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t2, height: 1.45)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (user.city != null) _MetaPill(Icons.location_on_outlined, user.city!),
                            _MetaPill(Icons.calendar_today_outlined, 'Since ${user.createdAt.year}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CLAN CARD ──
          SliverToBoxAdapter(
            child: myClan.when(
              data: (clan) => clan != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: _ClanCard(clan: clan, userId: user.id),
                    )
                  : const SizedBox(),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // ── OVERVIEW STATS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OVERVIEW', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.t3)),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                    children: [
                      _StatBox(icon: Icons.map_outlined, value: '${user.territoriesCaptured}', label: 'Territories', color: AppTheme.accent),
                      _StatBox(icon: Icons.directions_run_rounded, value: user.kmRan.toStringAsFixed(1), label: 'KM Ran', color: AppTheme.blue),
                      _StatBox(icon: Icons.bolt_rounded, value: '${user.territoriesCaptured}', label: 'Captures', color: AppTheme.green),
                      _StatBox(icon: Icons.shield_rounded, value: '${user.territoriesDefended}', label: 'Defenses', color: AppTheme.orange),
                      _StatBox(icon: Icons.local_fire_department_rounded, value: '${user.currentStreak}', label: 'Day Streak', color: AppTheme.red),
                      _StatBox(icon: Icons.emoji_events_rounded, value: '#—', label: 'Global Rank', color: AppTheme.purple),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── RECORDS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECORDS', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.t3)),
                  const SizedBox(height: 14),
                  _RecordRow(icon: Icons.directions_run_rounded, name: 'Best Run', value: '0.0 km', color: AppTheme.blue),
                  _divider(),
                  _RecordRow(icon: Icons.map_outlined, name: 'Most Territory in a Day', value: '0 zones', color: AppTheme.accent),
                  _divider(),
                  _RecordRow(icon: Icons.bolt_rounded, name: 'Captures This Season', value: '0', color: AppTheme.green),
                  _divider(),
                  _RecordRow(icon: Icons.local_fire_department_rounded, name: 'Longest Streak', value: '${user.maxStreak} days', color: AppTheme.orange),
                ],
              ),
            ),
          ),

          // ── ACTIVITY HEATMAP ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('ACTIVITY', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.t3)),
                      const Spacer(),
                      Text('Season III', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t4)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Days label row
                  Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['Jan','Feb','Mar','Apr','May','Jun']
                              .map((m) => Text(m, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.t4, fontWeight: FontWeight.w500)))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Heatmap grid
                  SizedBox(
                    height: 90,
                    child: Row(
                      children: [
                        // Day labels
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['M','','W','','F','','S']
                              .map((d) => SizedBox(
                                    width: 10,
                                    child: Text(d, style: GoogleFonts.inter(fontSize: 8, color: AppTheme.t4)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GridView.builder(
                            scrollDirection: Axis.horizontal,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 3,
                              crossAxisSpacing: 3,
                            ),
                            itemCount: 91,
                            itemBuilder: (_, i) {
                              final levels = [0.05, 0.18, 0.4, 0.7, 1.0];
                              final level = levels[i % 5];
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(level),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('0 active days', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t4)),
                      const Spacer(),
                      Text('Best month — —', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t4)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── SETTINGS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.share_outlined,
                    label: 'Share Profile',
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 52, color: AppTheme.sep),
                  _SettingsItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Account',
                    color: AppTheme.red,
                    onTap: () => _showDeleteDialog(context, ref),
                  ),
                  Divider(height: 1, indent: 52, color: AppTheme.sep),
                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppTheme.red,
                    onTap: () async {
                      await ref.read(authNotifierProvider.notifier).signOut();
                      if (context.mounted) context.go('/auth/login');
                    },
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

  Widget _divider() => Divider(height: 1, color: AppTheme.sep);

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This action is permanent. All your data will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {},
            child: const Text('Delete', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── CLAN CARD ──
class _ClanCard extends StatelessWidget {
  final dynamic clan;
  final String userId;
  const _ClanCard({required this.clan, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Glow effect
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.accent.withOpacity(0.3), Colors.transparent],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                        letterSpacing: 1, color: Colors.white.withOpacity(0.3))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(clan.name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.4)),
                        const SizedBox(width: 8),
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ClanTag(clan.rank ?? 'Street Crew', AppTheme.gold),
                        const SizedBox(width: 6),
                        _ClanTag(userId == clan.bossId ? 'Boss' : 'Member', AppTheme.accent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${clan.memberCount} members · #1 in ${clan.city ?? "City"}',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF00FF9D)),
                    ),
                  ],
                ),
              ),
              // Flag
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF1E1E32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: clan.flagUrl != null && clan.flagUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(imageUrl: clan.flagUrl!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.shield_rounded, color: AppTheme.accent, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClanTag extends StatelessWidget {
  final String text;
  final Color color;
  const _ClanTag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── STAT BOX ──
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatBox({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.t3)),
        ],
      ),
    );
  }
}

// ── RECORD ROW ──
class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String value;
  final Color color;
  const _RecordRow({required this.icon, required this.name, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accent)),
        ],
      ),
    );
  }
}

// ── META PILL ──
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
          Text(text, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── OUTLINE BTN ──
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.sep),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppTheme.t1),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.t1)),
          ],
        ),
      ),
    );
  }
}

// ── FILLED BTN ──
class _FilledBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilledBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.t1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── SETTINGS ITEM ──
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SettingsItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.t2, size: 20),
      title: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: color ?? AppTheme.t1)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.t4, size: 18),
      onTap: onTap,
    );
  }
}

// ── GRID PAINTER ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
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
