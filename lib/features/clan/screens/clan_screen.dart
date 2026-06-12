import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';
import 'package:turf_app/features/clan/screens/my_clan_screen.dart';

class ClanScreen extends ConsumerStatefulWidget {
  const ClanScreen({super.key});

  @override
  ConsumerState<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends ConsumerState<ClanScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final myClan = ref.watch(myClanProvider);
    return myClan.when(
      data: (clan) => clan != null ? MyClanScreen(clan: clan) : _buildBrowse(),
      loading: () => const Scaffold(backgroundColor: AppTheme.bg, body: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
      error: (_, __) => _buildBrowse(),
    );
  }

  Widget _buildBrowse() {
    final clansAsync = ref.watch(clansProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.white,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16, right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Clans', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                      const Spacer(),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppTheme.bg, shape: BoxShape.circle),
                        child: const Icon(Icons.search, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search
                  Container(
                    height: 44,
                    decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search clans by name...',
                        hintStyle: GoogleFonts.inter(color: AppTheme.t3, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.t3, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Open', 'Top Rated', 'New'].map((f) {
                        final isActive = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Clans list
          clansAsync.when(
            data: (clans) {
              final filtered = clans.where((c) {
                final matchSearch = _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchFilter = _filter == 'All' || (_filter == 'Open' && c.isOpen) || (_filter == 'Top Rated' && c.territoryCount > 50);
                return matchSearch && matchFilter;
              }).toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == 0) {
                      return Container(
                        color: AppTheme.white,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                        child: Text(
                          'All Clans · ${filtered.length} found',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.t3),
                        ),
                      );
                    }
                    return _buildClanCard(filtered[i - 1]);
                  },
                  childCount: filtered.length + 1,
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/clan/create'),
            backgroundColor: AppTheme.t1,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: Row(
              children: [
                const Icon(Icons.add, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Create Your Clan', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildClanCard(ClanModel clan) {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Flag
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: clan.flagUrl != null && clan.flagUrl!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: clan.flagUrl!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Icon(Icons.shield_rounded, color: AppTheme.accent, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(clan.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    _rankTag(clan.rank),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: AppTheme.t3),
                    const SizedBox(width: 3),
                    Text('${clan.memberCount}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                    const SizedBox(width: 10),
                    const Icon(Icons.map_outlined, size: 12, color: AppTheme.t3),
                    const SizedBox(width: 3),
                    Text('${clan.territoryCount} zones', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                    if (clan.isOpen) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Open', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.green)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Join button
          GestureDetector(
            onTap: () {
              ref.read(clanNotifierProvider.notifier).requestToJoin(clan.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(clan.isOpen ? 'Joined!' : 'Request sent!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppTheme.green,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: clan.isOpen ? AppTheme.green : AppTheme.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                clan.isOpen ? 'Join' : 'Request',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankTag(String rank) {
    Color color;
    switch (rank) {
      case 'Kingpin': color = AppTheme.gold; break;
      case 'Cartel':
      case 'Gang': color = AppTheme.accent; break;
      default: color = AppTheme.t3;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(rank, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
