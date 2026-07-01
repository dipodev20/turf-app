import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/feed/models/post_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

// ── COMMENTS ──────────────────────────────────────────────────────────────────
final commentsProvider = FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('comments')
      .select()
      .eq('post_id', postId)
      .order('created_at');
  return data.map((e) => CommentModel.fromJson(e)).toList();
});

// ── FEED NOTIFIER (единственный источник правды) ───────────────────────────────
class FeedNotifier extends AsyncNotifier<List<PostModel>> {
  String _filter = 'All';

  @override
  Future<List<PostModel>> build() async {
    return _fetchPosts(_filter);
  }

  Future<List<PostModel>> _fetchPosts(String filter) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;

    var query = supabase.from('posts').select();

    if (filter == 'Wars') {
      query = query.eq('type', 'war');
    } else if (filter == 'Captures') {
      query = query.eq('type', 'capture');
    } else if (filter == 'Achievements') {
      query = query.eq('type', 'achievement');
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(50);

    final posts = data.map((e) => PostModel.fromJson(e)).toList();
    if (userId == null) return posts;

    final likes = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId);
    final likedIds = (likes as List).map((l) => l['post_id'] as String).toSet();

    return posts.map((p) => p.copyWith(isLiked: likedIds.contains(p.id))).toList();
  }

  Future<void> setFilter(String filter) async {
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPosts(filter));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPosts(_filter));
  }

  Future<void> toggleLike(PostModel post) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final currentState = state.value ?? [];
    final index = currentState.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    // Optimistic update
    final optimistic = [...currentState];
    optimistic[index] = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );
    state = AsyncData(optimistic);

    try {
      if (post.isLiked) {
        await supabase.from('post_likes').delete()
            .eq('post_id', post.id)
            .eq('user_id', userId);
      } else {
        await supabase.from('post_likes').insert({
          'post_id': post.id,
          'user_id': userId,
        });
      }
      // Получить актуальный like_count из БД (триггер уже отработал)
      final fresh = await supabase
          .from('posts')
          .select('like_count')
          .eq('id', post.id)
          .single();
      final newCount = fresh['like_count'] as int? ?? 0;

      final latest = state.value ?? [];
      final idx = latest.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        final updated = [...latest];
        updated[idx] = latest[idx].copyWith(likeCount: newCount);
        state = AsyncData(updated);
      }
    } catch (e) {
      // Rollback
      state = AsyncData(currentState);
    }
  }

  Future<void> createPost({
    required String content,
    String type = 'regular',
    File? imageFile,
    List<File> imageFiles = const [],
    Map<String, dynamic>? metadata,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final userData = ref.read(currentUserProvider).value;
    if (userData?.clanId == null) return;

    // Загружаем все фото (до 3)
    final filesToUpload = imageFiles.isNotEmpty
        ? imageFiles
        : (imageFile != null ? [imageFile] : <File>[]);
    final List<String> uploadedUrls = [];
    for (int i = 0; i < filesToUpload.length && i < 3; i++) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'posts/$userId/${ts}_$i.jpg';
      await supabase.storage.from('media').upload(fileName, filesToUpload[i]);
      uploadedUrls.add(supabase.storage.from('media').getPublicUrl(fileName));
    }
    final String? firstUrl = uploadedUrls.isNotEmpty ? uploadedUrls.first : null;

    final clanData = await supabase
        .from('clans')
        .select('name, flag_url')
        .eq('id', userData!.clanId!)
        .single();

    await supabase.from('posts').insert({
      'id': const Uuid().v4(),
      'clan_id': userData.clanId,
      'clan_name': clanData['name'],
      'clan_flag_url': clanData['flag_url'],
      'author_id': userId,
      'author_name': userData.username,
      'author_avatar_url': userData.avatarUrl,
      'type': type,
      'content': content,
      'image_url': firstUrl,
      'image_urls': uploadedUrls,
      'metadata': metadata,
      'like_count': 0,
      'comment_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    await refresh();
  }

  Future<void> addComment(String postId, String content) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final userData = ref.read(currentUserProvider).value;

    await supabase.from('comments').insert({
      'id': const Uuid().v4(),
      'post_id': postId,
      'user_id': userId,
      'username': userData?.username ?? '',
      'avatar_url': userData?.avatarUrl,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Получить актуальный comment_count из БД (триггер)
    final fresh = await supabase
        .from('posts')
        .select('comment_count')
        .eq('id', postId)
        .single();
    final newCount = fresh['comment_count'] as int? ?? 0;

    final current = state.value ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final updated = [...current];
      updated[idx] = current[idx].copyWith(commentCount: newCount);
      state = AsyncData(updated);
    }

    ref.invalidate(commentsProvider(postId));
  }

  Future<void> deletePost(String postId) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('posts').delete()
        .eq('id', postId)
        .eq('author_id', userId);

    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p.id != postId).toList());
  }

  Future<void> deleteComment(String commentId, String postId) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('comments').delete()
        .eq('id', commentId)
        .eq('user_id', userId);

    // Получить актуальный comment_count из БД (триггер)
    final fresh = await supabase
        .from('posts')
        .select('comment_count')
        .eq('id', postId)
        .single();
    final newCount = fresh['comment_count'] as int? ?? 0;

    final current = state.value ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final updated = [...current];
      updated[idx] = current[idx].copyWith(commentCount: newCount);
      state = AsyncData(updated);
    }

    ref.invalidate(commentsProvider(postId));
  }
}

final feedNotifierProvider =
    AsyncNotifierProvider<FeedNotifier, List<PostModel>>(FeedNotifier.new);

// feedProvider удалён — используй feedNotifierProvider везде
