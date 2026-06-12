import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/map')) return 0;
    if (location.startsWith('/feed')) return 1;
    if (location.startsWith('/clan')) return 2;
    if (location.startsWith('/shop')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/map'); break;
      case 1: context.go('/feed'); break;
      case 2: context.go('/clan'); break;
      case 3: context.go('/shop'); break;
      case 4: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          border: Border(top: BorderSide(color: AppTheme.sep, width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Map', isActive: currentIndex == 0, onTap: () => _onTap(context, 0)),
                _NavItem(icon: Icons.tv_outlined, activeIcon: Icons.tv_rounded, label: 'Feed', isActive: currentIndex == 1, onTap: () => _onTap(context, 1)),
                _NavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Clan', isActive: currentIndex == 2, onTap: () => _onTap(context, 2)),
                _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Shop', isActive: currentIndex == 3, onTap: () => _onTap(context, 3)),
                _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile', isActive: currentIndex == 4, onTap: () => _onTap(context, 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.accent : AppTheme.t4,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? AppTheme.accent : AppTheme.t4,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 4, height: 4,
                decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              )
            else
              const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}
