import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:turf_app/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  VideoPlayerController? _videoController;

  final _pages = const [
    _PageData(
      isVideo: true,
      asset: 'assets/onboarding/onboard_1.mp4',
      title: 'Capture\nYour City',
      titleHighlight: 'Your City',
      subtitle: 'Run a route and return to your trail.\nClose the loop to claim the territory.',
    ),
    _PageData(
      isVideo: false,
      asset: 'assets/onboarding/onboard_2.jpg',
      title: 'Build\nYour Clan',
      titleHighlight: 'Your Clan',
      subtitle: 'Team up with friends, upload your flag\nand dominate the map together.',
    ),
    _PageData(
      isVideo: false,
      asset: 'assets/onboarding/onboard_3.jpg',
      title: 'Win\nThe Season',
      titleHighlight: 'The Season',
      subtitle: 'Compete in seasonal wars. The clan with\nthe most territory wins glory and rewards.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset('assets/onboarding/onboard_1.mp4');
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.setVolume(0);
    _videoController!.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/auth/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── PAGES ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              if (i == 0) {
                _videoController?.play();
              } else {
                _videoController?.pause();
              }
            },
            itemCount: _pages.length,
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),

          // ── BOTTOM UI ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black, Colors.black],
                  stops: [0.0, 0.25, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  _buildTitle(_pages[_currentPage]),
                  const SizedBox(height: 10),
                  // Subtitle
                  Text(
                    _pages[_currentPage].subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) =>
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppTheme.accent
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accent2],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Sign in
                  GestureDetector(
                    onTap: () => context.go('/auth/login'),
                    child: Text(
                      'Already have an account? Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageData page) {
    if (page.isVideo) {
      return SizedBox.expand(
        child: _videoController != null && _videoController!.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            : Container(color: Colors.black),
      );
    }
    return SizedBox.expand(
      child: Image.asset(page.asset, fit: BoxFit.cover),
    );
  }

  Widget _buildTitle(_PageData page) {
    final parts = page.title.split('\n');
    return Column(
      children: parts.map((part) {
        final isHighlight = page.titleHighlight.contains(part);
        return Text(
          part,
          style: GoogleFonts.inter(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: isHighlight ? AppTheme.accent : Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        );
      }).toList(),
    );
  }
}

class _PageData {
  final bool isVideo;
  final String asset;
  final String title;
  final String titleHighlight;
  final String subtitle;

  const _PageData({
    required this.isVideo,
    required this.asset,
    required this.title,
    required this.titleHighlight,
    required this.subtitle,
  });
}
