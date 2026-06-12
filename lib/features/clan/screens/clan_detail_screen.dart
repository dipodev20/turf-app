import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'package:turf_app/features/clan/models/clan_model.dart';

class ClanDetailScreen extends ConsumerWidget {
  final String clanId;
  const ClanDetailScreen({super.key, required this.clanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clansAsync = ref.watch(clansProvider);

    return clansAsync.when(
      data: (clans) {
        final clan = clans.firstWhere((c) => c.id == clanId, orElse: () => clans.first);
        return _buildDetail(context, ref, clan);
      },
      loading: () => const Scaffold(backgroundColor: AppTheme.bg, body: Center(child: CircularProgressIndicator(color: AppTheme.accent))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, ClanModel clan) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F18),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (clan.flagUrl != null && clan.flagUrl!.isNotEmpty)
                    CachedNetworkImage(imageUrl: clan.flagUrl!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [AppTheme.accent.withOpacity(0.25), const Color(0xFF0F0F18)],
                          center: Alignment.topRight,
                          radius: 1.2,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(clan.name, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.gold.withOpacity(0.25)),
                              ),
                              child: Text(clan.rank, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gold)),
                            ),
                          ],
                        ),
                        if (clan.slogan != null && clan.slogan!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(clan.slogan!, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6), fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _stat('${clan.memberCount}', 'Members', AppTheme.accent),
                      _statDivider(),
                      _stat('${clan.territoryCount}', 'Territories', AppTheme.green),
                      _statDivider(),
                      _stat(clan.rank, 'Rank', AppTheme.gold),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(clanNotifierProvider.notifier).requestToJoin(clan.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(clan.isOpen ? 'Joined!' : 'Request sent!'),
                          backgroundColor: AppTheme.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: clan.isOpen
                              ? LinearGradient(colors: [AppTheme.green, AppTheme.green.withOpacity(0.8)])
                              : const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: (clan.isOpen ? AppTheme.green : AppTheme.accent).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(
                          child: Text(
                            clan.isOpen ? 'Join Clan' : 'Request to Join',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 32, color: AppTheme.sep);
  }
}
