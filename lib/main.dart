import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:turf_app/core/constants/app_constants.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/core/router/app_router.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: AppLifecycleObserver(child: TurfApp())));
}

class TurfApp extends ConsumerWidget {
  const TurfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TURF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

// ── Lifecycle observer — online/offline ───────────────────────────────────────
class AppLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Вернулись в приложение — online
        _setOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Ушли в фон — offline
        ref.read(authNotifierProvider.notifier).setOffline();
        break;
      default:
        break;
    }
  }

  Future<void> _setOnline() async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('users').update({
      'is_online': true,
      'last_seen_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
