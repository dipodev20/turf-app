import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';
import 'package:uuid/uuid.dart';

// All clans list
final clansProvider = FutureProvider<List<ClanModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('clans')
      .select()
      .order('territory_count', ascending: false);
  return data.map((e) => ClanModel.fromJson(e)).toList();
});

// Current user clan
final myClanProvider = FutureProvider<ClanModel?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user?.clanId == null) return null;

  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('clans')
      .select()
      .eq('id', user!.clanId!)
      .single();
  return ClanModel.fromJson(data);
});

// Clan members
final clanMembersProvider = FutureProvider.family<List<ClanMemberModel>, String>((ref, clanId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('clan_members')
      .select('*, users(username, avatar_url, km_ran, territories_captured, is_online)')
      .eq('clan_id', clanId)
      .order('role');
  return data.map((e) {
    final user = e['users'] as Map<String, dynamic>? ?? {};
    return ClanMemberModel.fromJson({
      ...e,
      'username': user['username'],
      'avatar_url': user['avatar_url'],
      'km_ran': user['km_ran'],
      'territories_captured': user['territories_captured'],
      'is_online': user['is_online'],
    });
  }).toList();
});

// Clan messages (realtime)
final clanMessagesProvider = StreamProvider.family<List<ClanMessageModel>, String>((ref, clanId) async* {
  final supabase = ref.watch(supabaseProvider);

  Future<List<ClanMessageModel>> fetchMessages() async {
    final data = await supabase
        .from('clan_messages')
        .select()
        .eq('clan_id', clanId)
        .order('created_at', ascending: true);
    return data.map((e) => ClanMessageModel.fromJson(e)).toList();
  }

  // Initial load
  yield await fetchMessages();

  // Poll every 2 seconds for new messages
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await fetchMessages();
  }
});

  yield* controller.stream;
});

// Join requests
final joinRequestsProvider = FutureProvider.family<List<JoinRequestModel>, String>((ref, clanId) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('join_requests')
      .select('*, users(username, avatar_url, km_ran, territories_captured)')
      .eq('clan_id', clanId)
      .eq('status', 'pending');
  return data.map((e) {
    final user = e['users'] as Map<String, dynamic>? ?? {};
    return JoinRequestModel.fromJson({
      ...e,
      'username': user['username'],
      'avatar_url': user['avatar_url'],
      'km_ran': user['km_ran'],
      'territories_captured': user['territories_captured'],
    });
  }).toList();
});

class ClanNotifier extends AsyncNotifier<ClanModel?> {
  @override
  Future<ClanModel?> build() async {
    return ref.watch(myClanProvider).value;
  }

  Future<void> createClan({
    required String name,
    required String slogan,
    required String flagUrl,
    required String color,
    required bool isOpen,
  }) async {
    state = const AsyncLoading();
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;
      final clanId = const Uuid().v4();

      await supabase.from('clans').insert({
        'id': clanId,
        'name': name,
        'slogan': slogan,
        'flag_url': flagUrl,
        'color': color,
        'boss_id': userId,
        'member_count': 1,
        'territory_count': 0,
        'rank': 'Street Crew',
        'is_open': isOpen,
        'max_members': 30,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Add boss as member
      await supabase.from('clan_members').insert({
        'user_id': userId,
        'clan_id': clanId,
        'role': 'boss',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Update user's clan
      await supabase.from('users').update({'clan_id': clanId}).eq('id', userId);

      final data = await supabase.from('clans').select().eq('id', clanId).single();
      state = AsyncData(ClanModel.fromJson(data));
      ref.invalidate(myClanProvider);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> requestToJoin(String clanId) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser!.id;
    final userData = ref.read(currentUserProvider).value;

    await supabase.from('join_requests').insert({
      'id': const Uuid().v4(),
      'clan_id': clanId,
      'user_id': userId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> acceptRequest(JoinRequestModel request) async {
    final supabase = ref.read(supabaseProvider);

    // Update request status
    await supabase.from('join_requests').update({'status': 'accepted'}).eq('id', request.id);

    // Add member
    await supabase.from('clan_members').insert({
      'user_id': request.userId,
      'clan_id': request.clanId,
      'role': 'prospect',
      'joined_at': DateTime.now().toIso8601String(),
    });

    // Update user clan
    await supabase.from('users').update({'clan_id': request.clanId}).eq('id', request.userId);

    // Update member count
    await supabase.rpc('increment_member_count', params: {'clan_id': request.clanId});
    ref.invalidate(currentUserProvider);
    ref.invalidate(myClanProvider);

    ref.invalidate(clanMembersProvider(request.clanId));
    ref.invalidate(joinRequestsProvider(request.clanId));
  }

  Future<void> rejectRequest(String requestId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('join_requests').update({'status': 'rejected'}).eq('id', requestId);
  }

  Future<void> sendMessage(String clanId, String content) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser!.id;
    final userData = ref.read(currentUserProvider).value;

    await supabase.from('clan_messages').insert({
      'id': const Uuid().v4(),
      'clan_id': clanId,
      'user_id': userId,
      'username': userData?.username ?? '',
      'avatar_url': userData?.avatarUrl,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> leaveClan() async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser!.id;
    final userData = ref.read(currentUserProvider).value;
    if (userData?.clanId == null) return;

    await supabase.from('clan_members').delete()
        .eq('user_id', userId)
        .eq('clan_id', userData!.clanId!);

    await supabase.from('users').update({'clan_id': null}).eq('id', userId);
    await supabase.rpc('decrement_member_count', params: {'clan_id': userData.clanId});

    state = const AsyncData(null);
    ref.invalidate(myClanProvider);
    ref.invalidate(currentUserProvider);
  }

  Future<void> kickMember(String userId, String clanId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('clan_members').delete()
        .eq('user_id', userId).eq('clan_id', clanId);
    await supabase.from('users').update({'clan_id': null}).eq('id', userId);
    await supabase.rpc('decrement_member_count', params: {'clan_id': clanId});
    ref.invalidate(clanMembersProvider(clanId));
  }

    Future<void> deleteClan(String clanId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('clan_members').delete().eq('clan_id', clanId);
    await supabase.from('users').update({'clan_id': null}).eq('clan_id', clanId);
    await supabase.from('territories').delete().eq('clan_id', clanId);
    await supabase.from('clans').delete().eq('id', clanId);
    state = const AsyncData(null);
    ref.invalidate(myClanProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(clansProvider);
  }

  Future<void> deleteMessage(String messageId) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.from('clan_messages').delete().eq('id', messageId);
  }
}

final clanNotifierProvider = AsyncNotifierProvider<ClanNotifier, ClanModel?>(ClanNotifier.new);

