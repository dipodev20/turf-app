import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/clan/providers/clan_provider.dart';
import 'dart:io';

class CreateClanScreen extends ConsumerStatefulWidget {
  const CreateClanScreen({super.key});
  @override
  ConsumerState<CreateClanScreen> createState() => _CreateClanScreenState();
}

class _CreateClanScreenState extends ConsumerState<CreateClanScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final _nameController = TextEditingController();
  final _sloganController = TextEditingController();
  String _selectedColor = '#5B5BD6';
  String _arenaMode = 'local';
  bool _isOpen = false;
  File? _flagFile;
  bool _loading = false;

  final List<Map<String, dynamic>> _colors = [
    {'hex': '#5B5BD6', 'name': 'Violet'},
    {'hex': '#FF3B30', 'name': 'Red'},
    {'hex': '#FF9500', 'name': 'Orange'},
    {'hex': '#34C759', 'name': 'Green'},
    {'hex': '#FFD700', 'name': 'Gold'},
    {'hex': '#AF52DE', 'name': 'Purple'},
    {'hex': '#FF2D55', 'name': 'Pink'},
    {'hex': '#00C7BE', 'name': 'Teal'},
    {'hex': '#1C1C1E', 'name': 'Black'},
    {'hex': '#0A84FF', 'name': 'Blue'},
  ];

  final _steps = [
    {'title': 'Name', 'subtitle': 'Choose your clan name'},
    {'title': 'Slogan', 'subtitle': 'One line motto'},
    {'title': 'Flag', 'subtitle': 'Upload clan flag'},
    {'title': 'Style', 'subtitle': 'Color & settings'},
    {'title': 'Launch', 'subtitle': 'Final preview'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  Future<void> _pickFlag() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _flagFile = File(picked.path));
  }

  Future<String?> _uploadFlag() async {
    if (_flagFile == null) return null;
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final fileName = 'clan_flags/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('media').upload(fileName, _flagFile!);
    return supabase.storage.from('media').getPublicUrl(fileName);
  }

  void _next() {
    if (_currentStep < 4) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _createClan();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  Future<void> _createClan() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please enter a clan name'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep = 0);
      return;
    }
    setState(() => _loading = true);
    try {
      final flagUrl = await _uploadFlag();
      await ref.read(clanNotifierProvider.notifier).createClan(
        name: _nameController.text.trim(),
        slogan: _sloganController.text.trim(),
        flagUrl: flagUrl ?? '',
        color: _selectedColor,
        isOpen: _isOpen,
      );
      if (mounted) context.go('/clan');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _accentColor {
    final hex = _selectedColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 16, right: 16, bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _currentStep > 0 ? _back : () => context.pop(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Clan',
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(_steps[_currentStep]['subtitle']!,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              // Step counter badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_currentStep + 1} / 5',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Step pills
          Row(
            children: List.generate(5, (i) {
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppTheme.green
                              : isCurrent
                                  ? AppTheme.accent
                                  : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _steps[i]['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isDone
                              ? AppTheme.green
                              : isCurrent
                                  ? AppTheme.accent
                                  : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _loading ? null : _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentStep == 4
                        ? [AppTheme.accent, AppTheme.accent2]
                        : [_accentColor, _accentColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _accentColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == 4 ? 'Launch Clan' : 'Continue',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == 4
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Name ──────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIcon(
            svg: _SvgIcons.shield,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 20),
          Text('Name your clan',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('Choose a name that strikes fear into your enemies.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.5)),
          const SizedBox(height: 32),
          _darkLabel('Clan Name'),
          const SizedBox(height: 10),
          _darkField(_nameController, 'e.g. Iron Wolves', maxLength: 24),
          const SizedBox(height: 20),
          _infoCard(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Short names (2-3 words) are more memorable and intimidating.',
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Slogan ────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIcon(svg: _SvgIcons.pen, color: const Color(0xFFFF9500)),
          const SizedBox(height: 20),
          Text('Add a slogan',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('One line that defines your crew.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 32),
          _darkLabel('Slogan (optional)'),
          const SizedBox(height: 10),
          _darkField(_sloganController, 'e.g. The north is ours.', maxLength: 40),
          const SizedBox(height: 20),
          _infoCard(
            icon: Icons.format_quote_rounded,
            text: 'Shown below your clan name on the leaderboard.',
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Flag ──────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIcon(svg: _SvgIcons.flag, color: const Color(0xFF34C759)),
          const SizedBox(height: 20),
          Text('Upload your flag',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('Appears on every territory you capture on the map.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.5)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _pickFlag,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _flagFile != null
                      ? AppTheme.green
                      : Colors.white.withValues(alpha: 0.1),
                  width: _flagFile != null ? 2 : 1,
                ),
              ),
              child: _flagFile != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.file(_flagFile!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity),
                        ),
                        Positioned(
                          top: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.green, size: 14),
                                const SizedBox(width: 4),
                                Text('Selected',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Tap to change',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.7))),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.add_photo_alternate_outlined,
                              color: AppTheme.accent, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text('Choose from gallery',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('PNG, JPG · Recommended 3:2 ratio',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(
              icon: Icons.map_outlined,
              text: 'Your flag tiles across every captured zone on the map.'),
          const SizedBox(height: 8),
          _infoCard(
              icon: Icons.star_outline_rounded,
              text: 'Use custom artwork or your country\'s flag colors.'),
        ],
      ),
    );
  }

  // ── STEP 4: Style ─────────────────────────────────────────────────────────
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIcon(svg: _SvgIcons.palette, color: const Color(0xFFAF52DE)),
          const SizedBox(height: 20),
          Text('Style your clan',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('Pick an accent color and set membership rules.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 28),
          Text('ACCENT COLOR',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 14),
          // Color grid
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: _colors.map((c) {
              final isSelected = c['hex'] == _selectedColor;
              final hex = c['hex']!.replaceAll('#', '');
              final color = Color(int.parse('FF$hex', radix: 16));
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c['hex']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 14,
                            spreadRadius: 2)]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Selected color name
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _colors.firstWhere(
                    (c) => c['hex'] == _selectedColor)['name']!,
                key: ValueKey(_selectedColor),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('MEMBERSHIP',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_isOpen ? AppTheme.green : AppTheme.t3)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                    color: _isOpen ? AppTheme.green : AppTheme.t3,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Open membership',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text(
                        _isOpen
                            ? 'Anyone can join without approval'
                            : 'Members need your approval',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
                Switch(
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                    activeColor: AppTheme.green),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('COMPETITION MODE',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 12),
          _arenaOption('local', Icons.location_city_rounded,
              'Local City', 'Compete with clans in your city',
              const Color(0xFF0A84FF)),
          const SizedBox(height: 8),
          _arenaOption('global', Icons.public_rounded,
              'Global Arena', 'Battle clans worldwide on a virtual map',
              const Color(0xFFFF9500)),
        ],
      ),
    );
  }

  Widget _arenaOption(String value, IconData icon, String title,
      String subtitle, Color color) {
    final isSelected = _arenaMode == value;
    return GestureDetector(
      onTap: () => setState(() => _arenaMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : const Color(0xFF1A1A28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? color : Colors.white)),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? color
                      : Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 5: Preview ───────────────────────────────────────────────────────
  Widget _buildStep5() {
    final nameText = _nameController.text.trim().isEmpty
        ? 'Your Clan'
        : _nameController.text.trim();
    final sloganText = _sloganController.text.trim().isEmpty
        ? 'No slogan yet...'
        : _sloganController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _stepIcon(svg: _SvgIcons.rocket, color: AppTheme.accent),
          const SizedBox(height: 20),
          Text("Looking good!",
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('Here\'s how your clan will appear to others.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 28),

          // Clan card preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _accentColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                    color: _accentColor.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                // Glow
                Positioned(
                  top: -20, right: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _accentColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Flag preview
                        Container(
                          width: 64, height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _accentColor.withValues(alpha: 0.15),
                          ),
                          child: _flagFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_flagFile!,
                                      fit: BoxFit.cover))
                              : Icon(Icons.shield_rounded,
                                  color: _accentColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nameText,
                                  style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4)),
                              Text(sloganText,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Color bar
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _accentColor,
                          _accentColor.withValues(alpha: 0.2),
                        ]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _previewBadge('Street Crew', AppTheme.gold),
                        _previewBadge(
                            _isOpen ? '🔓 Open' : '🔒 Invite Only',
                            Colors.white.withValues(alpha: 0.3)),
                        _previewBadge('1 Member',
                            Colors.white.withValues(alpha: 0.3)),
                        _previewBadge(
                            _arenaMode == 'global'
                                ? '🌍 Global'
                                : '🏙️ Local',
                            _arenaMode == 'global'
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF0A84FF)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        _previewStat('0', 'Territories'),
                        _vDivider(),
                        _previewStat('1', 'Members'),
                        _vDivider(),
                        _previewStat('#—', 'Global Rank'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _infoCard(
            icon: Icons.rocket_launch_rounded,
            text: 'Once created, invite friends to grow your clan and dominate the map!',
          ),
        ],
      ),
    );
  }

  Widget _previewBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color == Colors.white.withValues(alpha: 0.3)
                  ? Colors.white.withValues(alpha: 0.6)
                  : color)),
    );
  }

  Widget _previewStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 32,
      color: Colors.white.withValues(alpha: 0.1));

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _stepIcon({required String svg, required Color color}) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: SizedBox(
          width: 32, height: 32,
          child: CustomPaint(painter: _SvgIconPainter(svg, color)),
        ),
      ),
    );
  }

  Widget _darkLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.8));
  }

  Widget _darkField(TextEditingController controller, String hint,
      {int maxLength = 100}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.2), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFF1A1A28),
        counterStyle: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: _accentColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.4))),
        ],
      ),
    );
  }
}

// ── SVG ИКОНКИ ────────────────────────────────────────────────────────────────
class _SvgIcons {
  static const shield = 'shield';
  static const pen = 'pen';
  static const flag = 'flag';
  static const palette = 'palette';
  static const rocket = 'rocket';
}

class _SvgIconPainter extends CustomPainter {
  final String icon;
  final Color color;
  const _SvgIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width;

    switch (icon) {
      case 'shield':
        final path = Path()
          ..moveTo(s * 0.5, s * 0.05)
          ..lineTo(s * 0.92, s * 0.22)
          ..lineTo(s * 0.92, s * 0.55)
          ..cubicTo(s * 0.92, s * 0.78, s * 0.72, s * 0.92, s * 0.5, s * 0.97)
          ..cubicTo(s * 0.28, s * 0.92, s * 0.08, s * 0.78, s * 0.08, s * 0.55)
          ..lineTo(s * 0.08, s * 0.22)
          ..close();
        canvas.drawPath(path, paint);
        // checkmark inside
        final check = Path()
          ..moveTo(s * 0.32, s * 0.52)
          ..lineTo(s * 0.45, s * 0.65)
          ..lineTo(s * 0.68, s * 0.38);
        canvas.drawPath(check, paint);
        break;

      case 'pen':
        final pen = Path()
          ..moveTo(s * 0.7, s * 0.1)
          ..lineTo(s * 0.9, s * 0.3)
          ..lineTo(s * 0.35, s * 0.85)
          ..lineTo(s * 0.1, s * 0.9)
          ..lineTo(s * 0.15, s * 0.65)
          ..close();
        canvas.drawPath(pen, paint);
        canvas.drawLine(
            Offset(s * 0.6, s * 0.2), Offset(s * 0.8, s * 0.4), paint);
        break;

      case 'flag':
        // Pole
        canvas.drawLine(
            Offset(s * 0.2, s * 0.08), Offset(s * 0.2, s * 0.95), paint);
        // Flag shape
        final flag = Path()
          ..moveTo(s * 0.2, s * 0.1)
          ..lineTo(s * 0.85, s * 0.22)
          ..lineTo(s * 0.85, s * 0.58)
          ..lineTo(s * 0.2, s * 0.46)
          ..close();
        canvas.drawPath(flag, paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.3));
        canvas.drawPath(flag, paint..style = PaintingStyle.stroke..color = color);
        break;

      case 'palette':
        // Circle
        canvas.drawCircle(
            Offset(s * 0.5, s * 0.5), s * 0.38,
            paint..style = PaintingStyle.stroke..color = color);
        // Color dots
        final dots = [
          Offset(s * 0.5, s * 0.15),
          Offset(s * 0.8, s * 0.35),
          Offset(s * 0.72, s * 0.72),
          Offset(s * 0.28, s * 0.72),
          Offset(s * 0.2, s * 0.35),
        ];
        for (final d in dots) {
          canvas.drawCircle(d, s * 0.07,
              paint..style = PaintingStyle.fill..color = color);
        }
        // White center cutout hint
        canvas.drawCircle(
            Offset(s * 0.62, s * 0.58), s * 0.13,
            paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.0));
        break;

      case 'rocket':
        // Body
        final body = Path()
          ..moveTo(s * 0.5, s * 0.05)
          ..cubicTo(s * 0.75, s * 0.05, s * 0.88, s * 0.3, s * 0.88, s * 0.55)
          ..lineTo(s * 0.5, s * 0.75)
          ..lineTo(s * 0.12, s * 0.55)
          ..cubicTo(s * 0.12, s * 0.3, s * 0.25, s * 0.05, s * 0.5, s * 0.05)
          ..close();
        canvas.drawPath(
            body, paint..style = PaintingStyle.stroke..color = color..strokeWidth = 2.2);
        // Window
        canvas.drawCircle(Offset(s * 0.5, s * 0.4), s * 0.1,
            paint..style = PaintingStyle.stroke..color = color);
        // Flames
        final flame = Path()
          ..moveTo(s * 0.35, s * 0.75)
          ..cubicTo(s * 0.35, s * 0.92, s * 0.45, s * 0.95, s * 0.5, s * 0.88)
          ..cubicTo(s * 0.55, s * 0.95, s * 0.65, s * 0.92, s * 0.65, s * 0.75);
        canvas.drawPath(
            flame, paint..style = PaintingStyle.stroke..color = color.withValues(alpha: 0.6));
        break;
    }
  }

  @override
  bool shouldRepaint(_SvgIconPainter old) =>
      old.icon != icon || old.color != color;
}
