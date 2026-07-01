import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/profile/screens/user_profile_screen.dart';

class MyClanScreen extends ConsumerStatefulWidget {
  final ClanModel clan;
  const MyClanScreen({super.key, required this.clan});

  @override
  ConsumerState<MyClanScreen> createState() => _MyClanScreenState();
}

class _MyClanScreenState extends ConsumerState<MyClanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  ClanMessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isBoss = currentUser?.id == widget.clan.bossId;

    // ── БАГ 7: Чёрный экран кикнутого ──────────────────────────────────────
    // Если clan_id стал null (кикнули) — редиректим на /clan
    ref.listen(authNotifierProvider, (prev, next) {
      final user = next.value;
      if (user != null && user.clanId == null) {
        if (mounted) context.go('/clan');
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(isBoss),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChat(currentUser?.id ?? ''),
                _buildMembers(isBoss),
                _buildTerritory(),
                _buildRanks(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isBoss) {
    return Container(
      color: const Color(0xFF0F0F18),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 16, right: 16, bottom: 16,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 160, height: 160,
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
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: widget.clan.flagUrl != null && widget.clan.flagUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: widget.clan.flagUrl!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFF1E1E32),
                          child: const Icon(Icons.shield_rounded, color: AppTheme.accent, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.clan.name,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.4)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _tag(widget.clan.rank, AppTheme.gold),
                        const SizedBox(width: 6),
                        if (isBoss) _tag('Boss', AppTheme.accent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.clan.memberCount} members · #1 ${widget.clan.city ?? ""}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF00FF9D))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showClanSettings(context, ref, isBoss),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings_outlined,
                      color: Colors.white.withValues(alpha: 0.5), size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.accent,
        unselectedLabelColor: AppTheme.t3,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 2,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Chat'),
          Tab(text: 'Members'),
          Tab(text: 'Territory'),
          Tab(text: 'Ranks'),
        ],
      ),
    );
  }

  // Extracts plain text from a message content, stripping any reply-quote
  // wrapper so nested replies never carry old quote/pipe fragments forward.
  String _extractPlainText(String content) {
    if (content.startsWith('↩ ') && content.contains('|')) {
      final firstPipe = content.indexOf('|');
      final secondPipe = content.indexOf('|', firstPipe + 1);
      if (firstPipe != -1 && secondPipe != -1) {
        return content.substring(secondPipe + 1);
      }
    }
    return content;
  }

  // ── БАГ 5: Reply блок-цитата ──────────────────────────────────────────────
  Widget _buildMessageContent(ClanMessageModel msg, bool isMe) {
    // Формат: "↩ username|quoted text|actual text"
    if (msg.content.startsWith('↩ ') && msg.content.contains('|')) {
      final firstPipe = msg.content.indexOf('|');
      final secondPipe = msg.content.indexOf('|', firstPipe + 1);
      if (firstPipe != -1 && secondPipe != -1) {
        final replyAuthor = msg.content.substring(2, firstPipe);
        final quotedText = msg.content.substring(firstPipe + 1, secondPipe);
        final actualText = msg.content.substring(secondPipe + 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Блок-цитата
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: isMe ? Colors.white : AppTheme.accent,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(replyAuthor,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white : AppTheme.accent)),
                  const SizedBox(height: 2),
                  Text(quotedText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppTheme.t3)),
                ],
              ),
            ),
            // Основной текст
            Text(actualText,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isMe ? Colors.white : AppTheme.t1)),
          ],
        );
      }
    }
    return Text(msg.content,
        style: GoogleFonts.inter(
            fontSize: 14, color: isMe ? Colors.white : AppTheme.t1));
  }

  Widget _buildChat(String currentUserId) {
    final messagesAsync = ref.watch(clanMessagesProvider(widget.clan.id));

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              // Автоскролл вниз при новых сообщениях
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
              return messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.t4),
                          const SizedBox(height: 12),
                          Text('No messages yet',
                              style: GoogleFonts.inter(color: AppTheme.t3, fontSize: 15)),
                          Text('Be first to say something 👋',
                              style: GoogleFonts.inter(color: AppTheme.t4, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        final isMe = msg.userId == currentUserId;
                        return _buildMessage(msg, isMe);
                      },
                    );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent)),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Reply banner
        if (_replyingTo != null)
          Container(
            color: AppTheme.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                    width: 3, height: 36, color: AppTheme.accent,
                    margin: const EdgeInsets.only(right: 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying to ${_replyingTo!.username}',
                          style: GoogleFonts.inter(fontSize: 11,
                              fontWeight: FontWeight.w700, color: AppTheme.accent)),
                      Text(_extractPlainText(_replyingTo!.content),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.t3),
                ),
              ],
            ),
          ),

        // Input
        SafeArea(
          top: false,
          child: Container(
          color: AppTheme.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _msgController,
                    style: GoogleFonts.inter(fontSize: 14),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message the clan...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.t3, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final text = _msgController.text.trim();
                  if (text.isEmpty) return;
                  final reply = _replyingTo;
                  setState(() => _replyingTo = null);
                  _msgController.clear();
                  // ── БАГ 5: правильный формат reply: "↩ username|quoted|text"
                  final quoted =
                      reply != null ? _extractPlainText(reply.content) : null;
                  final fullText = reply != null
                      ? '↩ ${reply.username}|$quoted|$text'
                      : text;
                  ref.read(clanNotifierProvider.notifier)
                      .sendMessage(widget.clan.id, fullText);
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent2]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 19),
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  void _showMessageMenu(BuildContext ctx, ClanMessageModel msg,
      bool isMe, bool isBoss) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: AppTheme.t4,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppTheme.accent),
              title: Text('Reply',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, color: AppTheme.accent)),
              onTap: () {
                Navigator.pop(ctx);
                if (mounted) setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text('Copy',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.content));
              },
            ),
            // ── БАГ 4: Delete сообщения ──────────────────────────────────
            if (isMe || isBoss)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.red),
                title: Text('Delete',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500, color: AppTheme.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clanNotifierProvider.notifier)
                      .deleteMessage(msg.id);
                },
              ),
            if (isBoss && !isMe)
              ListTile(
                leading: const Icon(Icons.person_remove_rounded,
                    color: AppTheme.red),
                title: Text('Kick from clan',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500, color: AppTheme.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmKick(msg.userId, msg.username);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmKick(String userId, String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Kick $username?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: const Text('This member will be removed from the clan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(clanNotifierProvider.notifier)
                  .kickMember(userId, widget.clan.id);
              ref.invalidate(clanMembersProvider(widget.clan.id));
            },
            child: const Text('Kick',
                style: TextStyle(
                    color: AppTheme.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ClanMessageModel msg, bool isMe) {
    final isBoss = widget.clan.bossId ==
        ref.read(supabaseProvider).auth.currentUser?.id;
    return GestureDetector(
      onLongPress: () => _showMessageMenu(context, msg, isMe, isBoss),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: 12, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: msg.userId))),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                  backgroundImage: msg.avatarUrl != null
                      ? CachedNetworkImageProvider(msg.avatarUrl!)
                      : null,
                  child: msg.avatarUrl == null
                      ? Text(
                          msg.username.isNotEmpty
                              ? msg.username[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 2),
                      child: Text(msg.username,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.t3)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.accent : AppTheme.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4)
                      ],
                    ),
                    // ── БАГ 5: используем _buildMessageContent ───────────
                    child: _buildMessageContent(msg, isMe),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── БАГ 6: Kick через Members вкладку (долгое нажатие) ───────────────────
  Widget _buildMembers(bool isBoss) {
    final membersAsync = ref.watch(clanMembersProvider(widget.clan.id));
    final requestsAsync = ref.watch(joinRequestsProvider(widget.clan.id));
    final currentUserId =
        ref.read(supabaseProvider).auth.currentUser?.id ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isBoss)
          requestsAsync.when(
            data: (requests) => requests.isEmpty
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Join Requests (${requests.length})',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppTheme.t3)),
                      const SizedBox(height: 10),
                      ...requests.map((r) => _buildRequestCard(r)),
                      const SizedBox(height: 20),
                    ],
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        membersAsync.when(
          data: (members) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Members (${members.length})',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.t3)),
              const SizedBox(height: 10),
              ...members.map((m) => _buildMemberCard(
                    m,
                    isBoss: isBoss,
                    isMe: m.userId == currentUserId,
                  )),
            ],
          ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _buildMemberCard(ClanMemberModel member,
      {required bool isBoss, required bool isMe}) {
    return GestureDetector(
      // Долгое нажатие — кик (только boss, не себя)
      onLongPress: (isBoss && !isMe && member.role != 'boss')
          ? () => _confirmKick(member.userId, member.username)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          // Подсветка — можно кикнуть
          border: (isBoss && !isMe && member.role != 'boss')
              ? Border.all(color: AppTheme.sep)
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
                  backgroundImage: member.avatarUrl != null
                      ? CachedNetworkImageProvider(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? Text(
                          member.username.isNotEmpty
                              ? member.username[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent))
                      : null,
                ),
                if (member.isOnline)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.username,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                      '${member.kmRan.toStringAsFixed(1)} km · ${member.territoriesCaptured} zones',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.t3)),
                ],
              ),
            ),
            _roleTag(member.role),
            if (isBoss && !isMe && member.role != 'boss') ...[
              const SizedBox(width: 8),
              Icon(Icons.more_vert,
                  size: 16, color: AppTheme.t4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(JoinRequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
            child: Text(
                request.username.isNotEmpty
                    ? request.username[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppTheme.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.username,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                    '${request.kmRan.toStringAsFixed(1)} km · ${request.territoriesCaptured} zones',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.t3)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => ref
                    .read(clanNotifierProvider.notifier)
                    .rejectRequest(request.id),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: AppTheme.red, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref
                    .read(clanNotifierProvider.notifier)
                    .acceptRequest(request),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child:
                      const Icon(Icons.check, color: AppTheme.green, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerritory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.map_outlined,
                size: 36, color: AppTheme.accent),
          ),
          const SizedBox(height: 16),
          Text('Territory Map',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text("View your clan's captured zones",
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3)),
        ],
      ),
    );
  }

  Widget _buildRanks() {
    final clansAsync = ref.watch(clansProvider);
    return clansAsync.when(
      data: (clans) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: clans.length,
        itemBuilder: (context, i) {
          final clan = clans[i];
          final isHighlighted = clan.id == widget.clan.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppTheme.accent.withValues(alpha: 0.08)
                  : AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: isHighlighted
                  ? Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('#${i + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: i == 0 ? AppTheme.gold : AppTheme.t3)),
                ),
                Container(
                  width: 36, height: 24,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(6)),
                  child: clan.flagUrl != null && clan.flagUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                              imageUrl: clan.flagUrl!, fit: BoxFit.cover),
                        )
                      : Container(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                          child: const Icon(Icons.shield_rounded,
                              size: 16, color: AppTheme.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(clan.name,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600))),
                Text('${clan.territoryCount} zones',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent)),
              ],
            ),
          );
        },
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showClanSettings(BuildContext context, WidgetRef ref, bool isBoss) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFC0C0C5),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Clan Settings',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (!isBoss)
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded,
                    color: Color(0xFFFF3B30)),
                title: Text('Leave Clan',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF3B30))),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(clanNotifierProvider.notifier)
                      .leaveClan();
                  if (context.mounted) context.go('/clan');
                },
              ),
            if (isBoss) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: Color(0xFF5B5BD6)),
                title: Text('Edit Clan',
                    style:
                        GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF3B30)),
                title: Text('Delete Clan',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF3B30))),
                onTap: () async {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Delete Clan?',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700)),
                      content: const Text(
                          'This will permanently delete the clan and all its territories.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref
                                .read(clanNotifierProvider.notifier)
                                .deleteClan(widget.clan.id);
                            if (context.mounted) context.go('/clan');
                          },
                          child: const Text('Delete',
                              style: TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _roleTag(String role) {
    Color color;
    switch (role) {
      case 'boss':
        color = AppTheme.gold;
        break;
      case 'underboss':
        color = AppTheme.accent;
        break;
      case 'soldier':
        color = AppTheme.green;
        break;
      default:
        color = AppTheme.t3;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(role[0].toUpperCase() + role.substring(1),
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
