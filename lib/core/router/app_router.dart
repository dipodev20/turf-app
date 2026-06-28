import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf_app/features/auth/screens/splash_screen.dart';
import 'package:turf_app/features/auth/screens/login_screen.dart';
import 'package:turf_app/features/auth/screens/register_screen.dart';
import 'package:turf_app/features/auth/screens/onboarding_screen.dart';
import 'package:turf_app/shared/widgets/main_shell.dart';
import 'package:turf_app/features/map/screens/map_screen.dart';
import 'package:turf_app/features/feed/screens/feed_screen.dart';
import 'package:turf_app/features/clan/screens/clan_screen.dart';
import 'package:turf_app/features/clan/screens/create_clan_screen.dart';
import 'package:turf_app/features/clan/screens/clan_detail_screen.dart';
import 'package:turf_app/features/shop/screens/shop_screen.dart';
import 'package:turf_app/features/profile/screens/profile_screen.dart';
import 'package:turf_app/features/profile/screens/edit_profile_screen.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'package:turf_app/features/profile/screens/user_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/map', builder: (c, s) => const MapScreen()),
          GoRoute(path: '/feed', builder: (c, s) => const FeedScreen()),
          GoRoute(
            path: '/clan',
            builder: (c, s) => const ClanScreen(),
            routes: [
              GoRoute(path: 'create', builder: (c, s) => const CreateClanScreen()),
              GoRoute(
                path: ':id',
                builder: (c, s) => ClanDetailScreen(clanId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/shop', builder: (c, s) => const ShopScreen()),
          GoRoute(
            path: '/profile',
            builder: (c, s) => const ProfileScreen(),
            routes: [
              GoRoute(path: 'edit', builder: (c, s) => const EditProfileScreen()),
              GoRoute(
                path: ':userId',
                builder: (c, s) => UserProfileScreen(userId: s.pathParameters['userId']!),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final location = state.matchedLocation;

      if (location == '/splash') return null;
      if (location == '/onboarding') return null;

      final isAuthScreen = location == '/auth/login' || location == '/auth/register';

      if (!isLoggedIn && !isAuthScreen) return '/auth/login';
      if (isLoggedIn && isAuthScreen) return '/map';
      return null;
    },
  );

  ref.listen(authStateProvider, (prev, next) {
    final isLoggedIn = next.value != null;
    final location = router.routerDelegate.currentConfiguration.fullPath;

    if (isLoggedIn && (location == '/auth/login' || location == '/auth/register')) {
      router.go('/map');
    } else if (!isLoggedIn && location != '/auth/login' && location != '/auth/register'
        && location != '/splash' && location != '/onboarding') {
      router.go('/auth/login');
    }
  });

  return router;
});
