import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/feed/models/post_model.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

final feedProvider = FutureProvider.family<List<PostModel>, String>((ref, filter) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;

  var query = supabase.from('posts').select();

  if (filter == 'Wars') {
    query = query.eq('type', 'war');
  } else if (filter == 'Captures') {
    query = query.eq('type', 'capture');
  } else if (filter == 'Achievements') {
    query = query.eq('type', 'achievement');
  }

  final data = await query.order('created_at', ascending: false).limit(30);

  // Check likes
  List<String> likedIds = [];
  if (userId != null) {
    final likes = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId);
    likedIds = likes.map<String>((e) => e['post_id'] as String).toList();
  }

  return data.map((e) => PostModel.fromJson({
    ...e,
    'is_liked': likedIds.contains(e['id']),
  })).toList();
});

final commentsProvider = FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('comments')
      .select()
      .eq('post_id', postId)
      .order('created_at');
  return data.map((e) => CommentModel.fromJson(e)).toList();
});

class FeedNotifier extends AsyncNotifier<List<PostModel>> {
  @override
  Future<List<PostModel>> build() async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;

    final data = await supabase
        .from('posts')
        .select()
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

  Future<void> toggleLike(PostModel post) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final currentState = state.value ?? [];
    final index = currentState.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    // Optimistic update FIRST - instant UI response
    final updated = [...currentState];
    if (post.isLiked) {
      updated[index] = post.copyWith(isLiked: false, likeCount: post.likeCount - 1);
    } else {
      updated[index] = post.copyWith(isLiked: true, likeCount: post.likeCount + 1);
    }
    state = AsyncData(updated);

    // Then update DB (trigger handles like_count)
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
    } catch (e) {
      // Rollback on error
      state = AsyncData(currentState);
    }
  }

  Future<void> createPost({
    required String content,
    String type = 'regular',
    File? imageFile,
    Map<String, dynamic>? metadata,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final userData = ref.read(currentUserProvider).value;
    if (userData?.clanId == null) return;

    String? imageUrl;
    if (imageFile != null) {
      final fileName = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('media').upload(fileName, imageFile);
      imageUrl = supabase.storage.from('media').getPublicUrl(fileName);
    }

    final clanData = await supabase.from('clans').select('name, flag_url').eq('id', userData!.clanId!).single();

    await supabase.from('posts').insert({
      'id': const Uuid().v4(),
      'clan_id': userData.clanId,
      'clan_name': clanData['name'],
      'clan_flag_url': clanData['flag_url'],
      'author_id': userId,
      'author_name': userData.username,
      'type': type,
      'content': content,
      'image_url': imageUrl,
      'metadata': metadata,
      'like_count': 0,
      'comment_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // state already updated optimistically
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

    // Increment comment count
    final currentState = state.value ?? [];
    final index = currentState.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final updated = [...currentState];
      final post = updated[index];
      updated[index] = PostModel(
        id: post.id, clanId: post.clanId, clanName: post.clanName,
        clanFlagUrl: post.clanFlagUrl, authorId: post.authorId, authorName: post.authorName,
        type: post.type, content: post.content, imageUrl: post.imageUrl,
        metadata: post.metadata, likeCount: post.likeCount,
        commentCount: post.commentCount + 1, isLiked: post.isLiked,
        city: post.city, createdAt: post.createdAt,
      );
      state = AsyncData(updated);
    }

    ref.invalidate(commentsProvider(postId));
  }

  Future<void> deletePost(String postId) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('posts').delete().eq('id', postId).eq('author_id', userId);
    final current = state.value ?? [];
    state = AsyncData(current.where((p) => p.id != postId).toList());
  }

  Future<void> deleteComment(String commentId, String postId) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('comments').delete().eq('id', commentId).eq('user_id', userId);
    ref.invalidate(commentsProvider(postId));
  }
}

final feedNotifierProvider = AsyncNotifierProvider<FeedNotifier, List<PostModel>>(FeedNotifier.new);

