import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _inController;
  late AnimationController _outController;

  // Каждая буква прилетает с разной стороны
  final _startOffsets = [
    const Offset(-3, -2),  // T — сверху-слева
    const Offset(0, 3),    // U — снизу
    const Offset(3, -1),   // R — справа
    const Offset(-2, 3),   // F — снизу-слева
  ];

  @override
  void initState() {
    super.initState();

    _inController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _outController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Буквы влетают
    await _inController.forward();
    // Пауза чтобы пользователь увидел
    await Future.delayed(const Duration(milliseconds: 700));
    // Буквы улетают
    await _outController.forward();
    // Переход
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) => user != null ? context.go('/map') : context.go('/onboarding'),
      loading: () => context.go('/onboarding'),
      error: (_, __) => context.go('/onboarding'),
    );
  }

  @override
  void dispose() {
    _inController.dispose();
    _outController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final letter = 'TURF'[i];

            // Анимация влёта
            final inAnim = Tween<Offset>(
              begin: _startOffsets[i],
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _inController,
              curve: Interval(
                i * 0.08,
                (i * 0.08 + 0.65).clamp(0.0, 1.0),
                curve: Curves.easeOutBack,
              ),
            ));

            final inFade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _inController,
                curve: Interval(
                  i * 0.08,
                  (i * 0.08 + 0.4).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
            );

            // Анимация вылёта — каждая буква улетает обратно откуда пришла
            final outAnim = Tween<Offset>(
              begin: Offset.zero,
              end: Offset(-_startOffsets[i].dx, -_startOffsets[i].dy),
            ).animate(CurvedAnimation(
              parent: _outController,
              curve: Interval(
                i * 0.06,
                (i * 0.06 + 0.7).clamp(0.0, 1.0),
                curve: Curves.easeInBack,
              ),
            ));

            final outFade = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                parent: _outController,
                curve: Interval(
                  i * 0.06,
                  (i * 0.06 + 0.5).clamp(0.0, 1.0),
                  curve: Curves.easeIn,
                ),
              ),
            );

            return AnimatedBuilder(
              animation: Listenable.merge([_inController, _outController]),
              builder: (_, __) {
                // Во время вылёта используем outAnim, иначе inAnim
                final offset = _outController.isAnimating || _outController.isCompleted
                    ? outAnim.value
                    : inAnim.value;
                final opacity = _outController.isAnimating || _outController.isCompleted
                    ? outFade.value
                    : inFade.value;

                return SlideTransition(
                  position: AlwaysStoppedAnimation(offset),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        letter,
                        style: GoogleFonts.orbitron(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB8A9FF),
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: AppTheme.accent.withValues(alpha: 0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 0),
                            ),
                            Shadow(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                              blurRadius: 48,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
