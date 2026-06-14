import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/feed/models/post_model.dart';
import 'package:turf_app/features/feed/providers/feed_provider.dart';
import 'package:turf_app/features/feed/screens/create_post_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Wars', 'Captures', 'Achievements'];

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(feedProvider(_filter));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 14,
                      left: 16, right: 16, bottom: 0,
                    ),
                    child: Row(
                      children: [
                        Text('Feed', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                        const Spacer(),
                        _headerBtn(Icons.notifications_outlined),
                        const SizedBox(width: 8),
                        _headerBtn(Icons.send_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Filter tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _filters.map((f) {
                        final isActive = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.t1 : AppTheme.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(f, style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.t2,
                              )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppTheme.sep),
                ],
              ),
            ),
          ),

          // Posts
          postsAsync.when(
            data: (posts) => posts.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.tv_off_outlined, size: 56, color: AppTheme.t4),
                          const SizedBox(height: 14),
                          Text('No posts yet', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.t3)),
                          const SizedBox(height: 6),
                          Text('Be the first to post something!', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.t4)),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildPost(posts[i]),
                      childCount: posts.length,
                    ),
                  ),
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppTheme.t1,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildPost(PostModel post) {
    return Container(
      color: AppTheme.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                  ),
                  child: ClipOval(
                    child: post.clanFlagUrl != null && post.clanFlagUrl!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: post.clanFlagUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppTheme.accent,
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.clanName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ],
                      ),
                      Text(
                        '${post.city ?? ""}  ·  ${timeago.format(post.createdAt)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: AppTheme.t3, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Content by type
          if (post.type == 'war') _buildWarBanner(post),
          if (post.type == 'capture') _buildCaptureBanner(post),
          if (post.type == 'achievement') _buildAchievementBanner(post),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            CachedNetworkImage(imageUrl: post.imageUrl!, fit: BoxFit.cover),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                _actionBtn(
                  icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: post.isLiked ? AppTheme.red : AppTheme.t2,
                  label: '${post.likeCount}',
                  onTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(post),
                ),
                const SizedBox(width: 16),
                _actionBtn(icon: Icons.chat_bubble_outline_rounded, label: '${post.commentCount}', onTap: () => _showComments(post)),
                const SizedBox(width: 16),
                _actionBtn(icon: Icons.share_outlined, label: '', onTap: () {}),
                const Spacer(),
                _actionBtn(icon: Icons.bookmark_border_rounded, label: '', onTap: () {}),
              ],
            ),
          ),

          // Caption
          if (post.content != null && post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${post.likeCount} likes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: post.clanName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.t1, fontSize: 14)),
                      TextSpan(text: '  ${post.content}', style: GoogleFonts.inter(color: AppTheme.t2, fontSize: 14)),
                    ]),
                  ),
                ],
              ),
            ),

          Divider(height: 1, color: AppTheme.sep),
        ],
      ),
    );
  }

  Widget _buildWarBanner(PostModel post) {
    final meta = post.metadata ?? {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF0F0F18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _warClan(meta['clan1_name'] ?? 'Clan 1', meta['clan1_score'] ?? 0, meta['clan1_flag']),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text('VS', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 3)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.red.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('⚔ WAR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.red)),
                ),
              ],
            ),
          ),
          _warClan(meta['clan2_name'] ?? 'Clan 2', meta['clan2_score'] ?? 0, meta['clan2_flag']),
        ],
      ),
    );
  }

  Widget _warClan(String name, int score, String? flagUrl) {
    return Column(
      children: [
        Container(
          width: 44, height: 30,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: flagUrl != null && flagUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: flagUrl, fit: BoxFit.cover)
                : Container(color: AppTheme.accent.withOpacity(0.3),
                    child: const Icon(Icons.shield_rounded, color: AppTheme.accent, size: 18)),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('$score', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }

  Widget _buildCaptureBanner(PostModel post) {
    final meta = post.metadata ?? {};
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFFF0EDE8),
      child: Stack(
        children: [
          Center(child: Icon(Icons.map_outlined, size: 80, color: Colors.black.withOpacity(0.04))),
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('+${meta['zones_captured'] ?? 0} zones',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          Positioned(
            bottom: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Text(meta['area_name'] ?? 'Territory captured',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBanner(PostModel post) {
    final meta = post.metadata ?? {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF0A1A0A)),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.green.withOpacity(0.3)),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppTheme.green, size: 32),
          ),
          const SizedBox(height: 10),
          Text(meta['title'] ?? 'Achievement Unlocked!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(meta['subtitle'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.green.withOpacity(0.25)),
            ),
            child: Text('🏆 ${meta['rank'] ?? 'New Rank'}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.green)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? AppTheme.t2),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.t2)),
          ],
        ],
      ),
    );
  }

  void _showComments(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post),
    );
  }

  Widget _headerBtn(IconData icon) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: AppTheme.bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: AppTheme.t1),
    );
  }
}

// Comments bottom sheet
class _CommentsSheet extends ConsumerStatefulWidget {
  final PostModel post;
  const _CommentsSheet({required this.post});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppTheme.t4, borderRadius: BorderRadius.circular(2))),
          Text('Comments', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          Divider(color: AppTheme.sep),
          Expanded(
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? Center(child: Text('No comments yet', style: GoogleFonts.inter(color: AppTheme.t3)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        return Dismissible(
                          key: Key(c.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete_rounded, color: Color(0xFFFF3B30)),
                          ),
                          onDismissed: (_) => ref.read(feedNotifierProvider.notifier).deleteComment(c.id, widget.post.id),
                          child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.accent.withOpacity(0.12),
                                child: Text(c.username.isNotEmpty ? c.username[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(children: [
                                    TextSpan(text: c.username, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.t1, fontSize: 13)),
                                    TextSpan(text: '  ${c.content}', style: GoogleFonts.inter(color: AppTheme.t2, fontSize: 13)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: GoogleFonts.inter(color: AppTheme.t3, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_controller.text.trim().isEmpty) return;
                    ref.read(feedNotifierProvider.notifier).addComment(widget.post.id, _controller.text.trim());
                    _controller.clear();
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
