import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turf_app/features/auth/models/user_model.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user);
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('users')
      .select()
      .eq('id', user.id)
      .single();

  return UserModel.fromJson(data);
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final supabase = ref.watch(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    // Listen for realtime changes to this user's data
    final channel = supabase
        .channel('user_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .subscribe();

    ref.onDispose(() => channel.unsubscribe());

    final data = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return UserModel.fromJson(data);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncLoading();
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await supabase.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'username': username,
          'coins': 100,
          'level': 1,
          'km_ran': 0,
          'territories_captured': 0,
          'territories_defended': 0,
          'current_streak': 0,
          'max_streak': 0,
          'share_location': true,
          'is_online': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        final data = await supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        state = AsyncData(UserModel.fromJson(data));
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Set online
        await supabase
            .from('users')
            .update({'is_online': true})
            .eq('id', response.user!.id);

        final data = await supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();

        state = AsyncData(UserModel.fromJson(data));
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> signOut() async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId != null) {
      await supabase
          .from('users')
          .update({'is_online': false})
          .eq('id', userId);
    }

    await supabase.auth.signOut();
    state = const AsyncData(null);
  }

  Future<void> updateProfile({
    String? username,
    String? bio,
    String? city,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (coverUrl != null) updates['cover_url'] = coverUrl;

    await supabase.from('users').update(updates).eq('id', userId);

    final data = await supabase
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    state = AsyncData(UserModel.fromJson(data));
        ref.invalidate(currentUserProvider);
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);
