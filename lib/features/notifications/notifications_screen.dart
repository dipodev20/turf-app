import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSection('Today'),
          _buildNotif(icon: Icons.shield_rounded, color: AppTheme.red,
              title: 'Territory Under Attack!',
              subtitle: 'A clan is trying to capture your zone',
              time: '2m ago'),
          _buildNotif(icon: Icons.person_add_rounded, color: AppTheme.green,
              title: 'New Join Request',
              subtitle: 'Someone wants to join your clan',
              time: '15m ago'),
          _buildNotif(icon: Icons.map_rounded, color: AppTheme.accent,
              title: 'Territory Captured!',
              subtitle: 'You captured 1 new zone',
              time: '1h ago'),
          _buildSection('Yesterday'),
          _buildNotif(icon: Icons.emoji_events_rounded, color: AppTheme.gold,
              title: 'Achievement Unlocked',
              subtitle: 'First Blood — captured your first territory',
              time: '1d ago'),
          _buildNotif(icon: Icons.chat_bubble_rounded, color: AppTheme.purple,
              title: 'New Clan Message',
              subtitle: 'New message in your clan chat',
              time: '1d ago'),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.t3)),
    );
  }

  Widget _buildNotif({required IconData icon, required Color color,
      required String title, required String subtitle, required String time}) {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.t4)),
        ],
      ),
    );
  }
}
