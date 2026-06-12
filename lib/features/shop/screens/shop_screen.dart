import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/shop/models/shop_model.dart';
import 'package:turf_app/features/shop/providers/shop_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Characters', 'Effects', 'Bundles', 'Coins'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 14,
                      left: 16, right: 16, bottom: 14,
                    ),
                    child: Row(
                      children: [
                        Text('Shop', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                        const Spacer(),
                        userAsync.when(
                          data: (user) => GestureDetector(
                            onTap: () => _tabController.animateTo(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 18),
                                  const SizedBox(width: 5),
                                  Text('${user?.coins ?? 0}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 16),
                                ],
                              ),
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppTheme.accent,
                    unselectedLabelColor: AppTheme.t3,
                    indicatorColor: AppTheme.accent,
                    indicatorWeight: 2,
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    tabAlignment: TabAlignment.start,
                    tabs: _tabs.map((t) => Tab(text: t)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAll(),
            _buildSkinsTab('character'),
            _buildSkinsTab('trail'),
            _buildBundles(),
            _buildCoins(),
          ],
        ),
      ),
    );
  }

  Widget _buildAll() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 10),
        _buildFeaturedBanner(),
        const SizedBox(height: 10),
        _buildSection(title: 'Characters', child: _buildSkinsGrid('character')),
        const SizedBox(height: 10),
        _buildSection(title: 'Trail Effects', child: _buildEffectsRow()),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.purple.withOpacity(0.3), Colors.transparent]),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.gold.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.gold, size: 12),
                          const SizedBox(width: 4),
                          Text('LIMITED · 2 days left', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Shadow\nRunner', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Elite character with dark trail', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.5))),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('800', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.3), decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                        const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 16),
                        const SizedBox(width: 3),
                        Text('499', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showPurchaseDialog(
                        const SkinModel(id: 'shadow_runner', name: 'Shadow Runner', type: 'character', price: 499, badge: 'hot'),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 16)],
                        ),
                        child: Text('Get Now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppTheme.purple.withOpacity(0.15), Colors.transparent]),
                ),
                child: Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E32),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.purple.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppTheme.purple, size: 36),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.t1)),
              const Spacer(),
              Text('See all ›', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSkinsTab(String type) {
    return Consumer(
      builder: (context, ref, _) {
        final skinsAsync = ref.watch(skinsProvider(type));
        return skinsAsync.when(
          data: (skins) => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78,
            ),
            itemCount: skins.length,
            itemBuilder: (context, i) => _buildSkinCard(skins[i]),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
    );
  }

  Widget _buildSkinsGrid(String type) {
    return Consumer(
      builder: (context, ref, _) {
        final skinsAsync = ref.watch(skinsProvider(type));
        return skinsAsync.when(
          data: (skins) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78,
            ),
            itemCount: skins.take(6).length,
            itemBuilder: (context, i) => _buildSkinCard(skins[i]),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, _) => const SizedBox(),
        );
      },
    );
  }

  Widget _buildSkinCard(SkinModel skin) {
    return GestureDetector(
      onTap: () {
        if (skin.isOwned || skin.isFree) {
          ref.read(shopNotifierProvider.notifier).equipSkin(skin);
        } else {
          _showPurchaseDialog(skin);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: skin.isEquipped ? AppTheme.accent : skin.isOwned ? AppTheme.green : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            if (skin.badge != null)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _badgeColor(skin.badge!).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(skin.badge!.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _badgeColor(skin.badge!))),
                ),
              )
            else
              const SizedBox(height: 16),
            const Spacer(),
            Icon(
              skin.type == 'character' ? Icons.person_rounded : Icons.auto_awesome_rounded,
              size: 44,
              color: skin.isOwned ? AppTheme.accent : AppTheme.t4,
            ),
            const Spacer(),
            Text(skin.name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (skin.isEquipped)
              Text('Equipped', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent))
            else if (skin.isOwned || skin.isFree)
              Text('Owned ✓', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 12),
                  const SizedBox(width: 2),
                  Text('${skin.price}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectsRow() {
    final effectsAsync = ref.watch(skinsProvider('trail'));
    return effectsAsync.when(
      data: (effects) => SizedBox(
        height: 130,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: effects.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final e = effects[i];
            return GestureDetector(
              onTap: () => e.isOwned ? ref.read(shopNotifierProvider.notifier).equipSkin(e) : _showPurchaseDialog(e),
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: e.isEquipped ? AppTheme.accent : Colors.transparent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 60, width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFF0D0D1A), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.purple, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(e.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    if (e.isOwned)
                      Text('Owned', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600))
                    else
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 11),
                          const SizedBox(width: 2),
                          Text('${e.price}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.t3)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => const SizedBox(),
    );
  }

  Widget _buildBundles() {
    final bundlesAsync = ref.watch(bundlesProvider);
    return bundlesAsync.when(
      data: (bundles) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bundles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildBundleCard(bundles[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildBundleCard(BundleModel bundle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bundle.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(bundle.description, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5, runSpacing: 4,
                  children: bundle.itemIds.map((id) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                    child: Text(id, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                  )).toList(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${(bundle.discountedPrice / 100).toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('Save ${bundle.discountPercent.toInt()}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoins() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
      ),
      itemCount: coinPackages.length,
      itemBuilder: (context, i) {
        final pkg = coinPackages[i];
        return GestureDetector(
          onTap: () => _showCoinPurchase(pkg),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pkg.isPopular ? AppTheme.accent : Colors.transparent, width: 2),
            ),
            child: Column(
              children: [
                if (pkg.isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Most Popular', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  )
                else
                  const SizedBox(height: 21),
                const Spacer(),
                const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 36),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${pkg.coins}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    if (pkg.bonusCoins > 0) ...[
                      const SizedBox(width: 5),
                      Text('+${pkg.bonusCoins}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.green)),
                    ],
                  ],
                ),
                if (pkg.bonusCoins > 0)
                  Text('+${((pkg.bonusCoins / pkg.coins) * 100).toInt()}% bonus', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.green)),
                const SizedBox(height: 4),
                Text('\$${pkg.priceUsd.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.t3)),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPurchaseDialog(SkinModel skin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.t4, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.person_rounded, size: 44, color: AppTheme.accent),
            ),
            const SizedBox(height: 14),
            Text(skin.name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 20),
                const SizedBox(width: 5),
                Text('${skin.price} coins', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ref.read(shopNotifierProvider.notifier).purchaseSkin(skin);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success ? '${skin.name} purchased!' : 'Not enough coins'),
                      backgroundColor: success ? AppTheme.green : AppTheme.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Text('Purchase', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.t3))),
          ],
        ),
      ),
    );
  }

  void _showCoinPurchase(CoinPackage pkg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.t4, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 64),
            const SizedBox(height: 12),
            Text('${pkg.coins + pkg.bonusCoins} Coins', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('\$${pkg.priceUsd.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.t3)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(shopNotifierProvider.notifier).addCoins(pkg.coins + pkg.bonusCoins);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${pkg.coins + pkg.bonusCoins} coins added!'),
                      backgroundColor: AppTheme.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Text('Buy for \$${pkg.priceUsd.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.t3))),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'new': return AppTheme.red;
      case 'hot': return AppTheme.orange;
      case 'limited': return AppTheme.gold;
      default: return AppTheme.accent;
    }
  }
}
