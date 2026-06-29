import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/models/user_model.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';
import 'package:turf_app/features/clan/screens/clan_detail_screen.dart';
import 'package:turf_app/features/feed/models/post_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Посты конкретного юзера
final userPostsProvider = FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('posts')
      .select()
      .eq('author_id', userId)
      .order('created_at', ascending: false)
      .limit(20);
  return data.map((e) => PostModel.fromJson(e)).toList();
});

// Клан юзера
final userClanProvider = FutureProvider.family<ClanModel?, String>((ref, clanId) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final data = await supabase.from('clans').select().eq('id', clanId).single();
    return ClanModel.fromJson(data);
  } catch (_) { return null; }
});

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

class _UserProfileBody extends ConsumerWidget {
  final UserModel user;
  const _UserProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(user.id));
    final clanAsync = user.clanId != null
        ? ref.watch(userClanProvider(user.clanId!))
        : const AsyncData<ClanModel?>(null);

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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover
                      Container(
                        height: 140, width: double.infinity,
                        color: const Color(0xFF1C1C1E),
                        child: user.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user.coverUrl!, fit: BoxFit.cover)
                            : Stack(children: [
                                Positioned.fill(
                                    child: CustomPaint(painter: _GridPainter())),
                              ]),
                      ),
                      // Back
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8, left: 12,
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
                                border: Border.all(color: AppTheme.white, width: 4),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 16)],
                              ),
                              child: ClipOval(
                                child: user.avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: user.avatarUrl!, fit: BoxFit.cover)
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
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  color: user.isActuallyOnline ? AppTheme.green : AppTheme.t4,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.white, width: 2.5),
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
                            Text(user.username,
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                            const SizedBox(width: 7),
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                  color: AppTheme.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Online статус
                        Row(
                          children: [
                            Container(
                              width: 7, height: 7,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: user.isActuallyOnline ? AppTheme.green : AppTheme.t4,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              user.lastSeenText,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: user.isActuallyOnline ? AppTheme.green : AppTheme.t3,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(user.bio!,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppTheme.t2, height: 1.45)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
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

          // ── CLAN CARD ──
          if (user.clanId != null)
            SliverToBoxAdapter(
              child: clanAsync.when(
                data: (clan) => clan == null
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ClanDetailScreen(clanId: clan.id))),
                          child: _ClanCard(clan: clan, userId: user.id),
                        ),
                      ),
                loading: () => const SizedBox(
                    height: 80,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent))),
                error: (_, __) => const SizedBox(),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppTheme.t3)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                          icon: Icons.map_outlined,
                          value: '${user.territoriesCaptured}',
                          label: 'Territories',
                          color: AppTheme.accent)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(
                          icon: Icons.directions_run_rounded,
                          value: user.kmRan.toStringAsFixed(1),
                          label: 'KM Ran',
                          color: AppTheme.blue)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          value: '${user.currentStreak}',
                          label: 'Streak',
                          color: AppTheme.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                          icon: Icons.shield_rounded,
                          value: '${user.territoriesDefended}',
                          label: 'Defenses',
                          color: AppTheme.orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(
                          icon: Icons.emoji_events_rounded,
                          value: 'Lv.${user.level}',
                          label: 'Level',
                          color: AppTheme.gold)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(
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

          // ── RECORDS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECORDS',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppTheme.t3)),
                  const SizedBox(height: 14),
                  _RecordRow(Icons.directions_run_rounded, 'Best Run',
                      '${user.kmRan.toStringAsFixed(1)} km', AppTheme.blue),
                  Divider(height: 1, color: AppTheme.sep),
                  _RecordRow(Icons.map_outlined, 'Territories Captured',
                      '${user.territoriesCaptured}', AppTheme.accent),
                  Divider(height: 1, color: AppTheme.sep),
                  _RecordRow(Icons.shield_rounded, 'Territories Defended',
                      '${user.territoriesDefended}', AppTheme.orange),
                  Divider(height: 1, color: AppTheme.sep),
                  _RecordRow(Icons.local_fire_department_rounded,
                      'Longest Streak', '${user.maxStreak} days', AppTheme.red),
                ],
              ),
            ),
          ),

          // ── POSTS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('POSTS',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppTheme.t3)),
            ),
          ),
          postsAsync.when(
            data: (posts) => posts.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No posts yet',
                            style: GoogleFonts.inter(color: AppTheme.t3)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PostCard(post: posts[i]),
                      childCount: posts.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent)),
                )),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── CLAN CARD ──────────────────────────────────────────────────────────────────
class _ClanCard extends StatelessWidget {
  final ClanModel clan;
  final String userId;
  const _ClanCard({required this.clan, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.accent.withValues(alpha: 0.25), Colors.transparent],
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
                    Text('CLAN',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.3))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(clan.name,
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.4)),
                        const SizedBox(width: 6),
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                              color: AppTheme.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Tag(clan.rank, AppTheme.gold),
                        const SizedBox(width: 6),
                        _Tag(userId == clan.bossId ? 'Boss' : 'Member',
                            AppTheme.accent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${clan.memberCount} members · ${clan.territoryCount} zones',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF00FF9D)),
                    ),
                  ],
                ),
              ),
              // Flag
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF1E1E32),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: clan.flagUrl != null && clan.flagUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                            imageUrl: clan.flagUrl!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.shield_rounded,
                        color: AppTheme.accent, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── POST CARD ─────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                // Двойной аватар
                SizedBox(
                  width: 48, height: 36,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0, top: 2,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: post.clanFlagUrl != null &&
                                    post.clanFlagUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: post.clanFlagUrl!,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.accent,
                                    child: const Icon(Icons.shield_rounded,
                                        color: Colors.white, size: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        '${post.clanName} · ${timeago.format(post.createdAt)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.t3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            CachedNetworkImage(imageUrl: post.imageUrl!, fit: BoxFit.cover),
          ],
          if (post.content != null && post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(post.content!,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t2)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              children: [
                Icon(
                  post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 17,
                  color: post.isLiked ? AppTheme.red : AppTheme.t3,
                ),
                const SizedBox(width: 4),
                Text('${post.likeCount}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 17, color: AppTheme.t3),
                const SizedBox(width: 4),
                Text('${post.commentCount}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                const SizedBox(width: 12),
                Text(timeago.format(post.createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.t4)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.sep),
        ],
      ),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.value,
      required this.label, required this.color});
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
                  fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.t3)),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String value;
  final Color color;
  const _RecordRow(this.icon, this.name, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
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
                  fontSize: 12, color: AppTheme.t3, fontWeight: FontWeight.w500)),
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
