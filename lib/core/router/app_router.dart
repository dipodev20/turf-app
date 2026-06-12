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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuth = state.matchedLocation.startsWith('/auth');

      if (isSplash) return null;
      if (!isLoggedIn && !isAuth) return '/auth/login';
      if (isLoggedIn && isAuth) return '/map';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(
        path: '/auth',
        redirect: (c, s) => '/auth/login',
        routes: [
          GoRoute(path: 'login', builder: (c, s) => const LoginScreen()),
          GoRoute(path: 'register', builder: (c, s) => const RegisterScreen()),
        ],
      ),
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
            ],
          ),
        ],
      ),
    ],
  );
});
