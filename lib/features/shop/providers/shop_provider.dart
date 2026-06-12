import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/shop/models/shop_model.dart';

final skinsProvider = FutureProvider.family<List<SkinModel>, String>((ref, type) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;

  final data = await supabase
      .from('shop_items')
      .select()
      .eq('type', type)
      .order('created_at');

  List<String> ownedIds = [];
  String? equippedId;

  if (userId != null) {
    final owned = await supabase
        .from('user_items')
        .select('item_id')
        .eq('user_id', userId);
    ownedIds = owned.map<String>((e) => e['item_id'] as String).toList();

    final userData = await supabase
        .from('users')
        .select('skin_id, trail_id')
        .eq('id', userId)
        .single();

    equippedId = type == 'character' ? userData['skin_id'] : userData['trail_id'];
  }

  return data.map((e) => SkinModel.fromJson({
    ...e,
    'is_owned': ownedIds.contains(e['id']) || (e['is_free'] ?? false),
    'is_equipped': e['id'] == equippedId,
  })).toList();
});

final bundlesProvider = FutureProvider<List<BundleModel>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase.from('bundles').select().order('discounted_price');
  return data.map((e) => BundleModel.fromJson(e)).toList();
});

class ShopNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<bool> purchaseSkin(SkinModel skin) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    // Check coins
    final userData = await supabase
        .from('users')
        .select('coins')
        .eq('id', userId)
        .single();

    final coins = userData['coins'] as int;
    if (coins < skin.price && !skin.isFree) return false;

    // Deduct coins
    if (!skin.isFree) {
      await supabase
          .from('users')
          .update({'coins': coins - skin.price})
          .eq('id', userId);
    }

    // Add to owned items
    await supabase.from('user_items').insert({
      'user_id': userId,
      'item_id': skin.id,
      'purchased_at': DateTime.now().toIso8601String(),
    });

    ref.invalidate(skinsProvider);
    ref.invalidate(currentUserProvider);
    return true;
  }

  Future<void> equipSkin(SkinModel skin) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final field = skin.type == 'character' ? 'skin_id' : 'trail_id';
    await supabase.from('users').update({field: skin.id}).eq('id', userId);

    ref.invalidate(skinsProvider);
    ref.invalidate(currentUserProvider);
  }

  Future<void> addCoins(int amount) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final userData = await supabase
        .from('users')
        .select('coins')
        .eq('id', userId)
        .single();

    final currentCoins = userData['coins'] as int;
    await supabase
        .from('users')
        .update({'coins': currentCoins + amount})
        .eq('id', userId);

    ref.invalidate(currentUserProvider);
  }
}

final shopNotifierProvider = NotifierProvider<ShopNotifier, void>(ShopNotifier.new);
