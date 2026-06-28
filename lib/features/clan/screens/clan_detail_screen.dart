import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';
import 'package:turf_app/features/feed/providers/feed_provider.dart';
import 'package:turf_app/features/feed/models/post_model.dart';
import 'package:turf_app/features/profile/screens/user_profile_screen.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';

// Провайдер для загрузки одного клана по id
final clanByIdProvider = FutureProvider.family<ClanModel?, String>((ref, clanId) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final data = await supabase.from('clans').select().eq('id', clanId).single();
    return ClanModel.fromJson(data);
  } catch (_) { return null; }
});

// Провайдер для постов конкретного клана
final clanPostsProvider = FutureProvider.family<List<PostModel>, String>((ref, clanId) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  final data = await supabase
      .from('posts')
      .select()
      .eq('clan_id', clanId)
      .order('created_at', ascending: false)
      .limit(20);
  final posts = data.map((e) => PostModel.fromJson(e)).toList();
  if (userId == null) return posts;
  final likes = await supabase
      .from('post_likes').select('post_id').eq('user_id', userId);
  final likedIds = (likes as List).map((l) => l['post_id'] as String).toSet();
  return posts.map((p) => p.copyWith(isLiked: likedIds.contains(p.id))).toList();
});

class ClanDetailScreen extends ConsumerWidget {
  final String clanId;
  const ClanDetailScreen({super.key, required this.clanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clanAsync = ref.watch(clanByIdProvider(clanId));
    return clanAsync.when(
      data: (clan) => clan == null
          ? const Scaffold(body: Center(child: Text('Clan not found')))
          : _ClanDetailBody(clan: clan),
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ClanDetailBody extends ConsumerWidget {
  final ClanModel clan;
  const _ClanDetailBody({required this.clan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(clanMembersProvider(clan.id));
    final postsAsync = ref.watch(clanPostsProvider(clan.id));
    final currentUserId = ref.read(supabaseProvider).auth.currentUser?.id;
    final isMember = ref.watch(currentUserProvider).value?.clanId == clan.id;

    // Цвет клана
    final hex = clan.color.replaceAll('#', '');
    final clanColor = Color(int.parse('FF$hex', radix: 16));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // ── HERO ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F18),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  clan.flagUrl != null && clan.flagUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: clan.flagUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                clanColor.withValues(alpha: 0.3),
                                const Color(0xFF0F0F18)
                              ],
                              center: Alignment.topRight,
                              radius: 1.2,
                            ),
                          ),
                        ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85)
                        ],
                      ),
                    ),
                  ),
                  // Clan info
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(clan.name,
                                      style: GoogleFonts.inter(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppTheme.gold.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(clan.rank,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.gold)),
                                  ),
                                ],
                              ),
                              if (clan.slogan != null &&
                                  clan.slogan!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(clan.slogan!,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.55),
                                        fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _stat('${clan.memberCount}', 'Members', AppTheme.accent),
                  _divider(),
                  _stat('${clan.territoryCount}', 'Zones', AppTheme.green),
                  _divider(),
                  _stat(clan.rank, 'Rank', AppTheme.gold),
                  _divider(),
                  _stat(clan.isOpen ? 'Open' : 'Closed',
                      'Access',
                      clan.isOpen ? AppTheme.green : AppTheme.t3),
                ],
              ),
            ),
          ),

          // ── JOIN BUTTON (если не член) ──
          if (!isMember)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: GestureDetector(
                  onTap: () {
                    ref.read(clanNotifierProvider.notifier).requestToJoin(clan.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(clan.isOpen ? 'Joined!' : 'Request sent!'),
                      backgroundColor: AppTheme.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: clan.isOpen
                            ? [AppTheme.green, AppTheme.green.withValues(alpha: 0.8)]
                            : [AppTheme.accent, AppTheme.accent2],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: (clan.isOpen ? AppTheme.green : AppTheme.accent)
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Center(
                      child: Text(
                        clan.isOpen ? '⚡ Join Clan' : '📨 Request to Join',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── MEMBERS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('MEMBERS',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppTheme.t3)),
            ),
          ),
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) => SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(userId: m.userId))),
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      AppTheme.accent.withValues(alpha: 0.12),
                                  backgroundImage: m.avatarUrl != null
                                      ? CachedNetworkImageProvider(m.avatarUrl!)
                                      : null,
                                  child: m.avatarUrl == null
                                      ? Text(
                                          m.username.isNotEmpty
                                              ? m.username[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.accent))
                                      : null,
                                ),
                                if (m.isOnline)
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                if (m.role == 'boss')
                                  Positioned(
                                    top: 0, right: 0,
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(Icons.star_rounded,
                                          size: 9, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(m.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.t2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const SizedBox(
                  height: 90,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.accent))),
              error: (_, __) => const SizedBox(),
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
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No posts yet',
                            style: GoogleFonts.inter(color: AppTheme.t3)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildPost(context, ref, posts[i], currentUserId),
                      childCount: posts.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
            error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildPost(BuildContext context, WidgetRef ref,
      PostModel post, String? currentUserId) {
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
                // ── Двойной аватар: клан + автор ──
                SizedBox(
                  width: 48, height: 38,
                  child: Stack(
                    children: [
                      // Clan flag (фон)
                      Positioned(
                        left: 0, top: 0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: post.clanFlagUrl != null && post.clanFlagUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: post.clanFlagUrl!, fit: BoxFit.cover)
                                : Container(
                                    color: AppTheme.accent,
                                    child: const Icon(Icons.shield_rounded,
                                        color: Colors.white, size: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '${post.clanName} · ${timeago.format(post.createdAt)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.t3),
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(post.content!,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t2)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Icon(
                  post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: post.isLiked ? AppTheme.red : AppTheme.t3,
                ),
                const SizedBox(width: 4),
                Text('${post.likeCount}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.t3)),
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: AppTheme.t3),
                const SizedBox(width: 4),
                Text('${post.commentCount}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.t3)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.sep),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t3)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppTheme.sep);
}
