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
  bool _isOpen = false;
  File? _flagFile;
  bool _loading = false;

  final List<String> _colors = [
    '#5B5BD6', '#FF3B30', '#FF9500', '#34C759', '#FFD700',
    '#AF52DE', '#FF2D55', '#00C7BE', '#0D0D0D', '#FF6B6B',
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
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _createClan();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Column(
        children: [
          // Header + progress
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16),
            decoration: BoxDecoration(color: AppTheme.white, border: Border(bottom: BorderSide(color: AppTheme.sep))),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _currentStep > 0 ? _back : () => context.pop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppTheme.bg, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Create Clan', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(5, (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? AppTheme.accent : AppTheme.bg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Step ${_currentStep + 1} of 5', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildStep1(), _buildStep2(), _buildStep3(), _buildStep4(), _buildStep5()],
            ),
          ),

          // Nav buttons
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(color: AppTheme.white, border: Border(top: BorderSide(color: AppTheme.sep))),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  GestureDetector(
                    onTap: _back,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: _loading ? null : _next,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _currentStep == 4
                            ? const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2])
                            : null,
                        color: _currentStep == 4 ? null : AppTheme.t1,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _currentStep == 4
                            ? [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]
                            : [],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _currentStep == 4 ? '🚀  Launch Clan' : 'Continue',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐺', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Name your clan', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Choose a name that strikes fear into your enemies.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3, height: 1.4)),
          const SizedBox(height: 28),
          _inputLabel('Clan Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 24,
            style: GoogleFonts.inter(fontSize: 15),
            decoration: _fieldDeco('e.g. Iron Wolves'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✍️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Add a slogan', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('One line that represents your crew.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3)),
          const SizedBox(height: 28),
          _inputLabel('Slogan'),
          const SizedBox(height: 8),
          TextField(
            controller: _sloganController,
            maxLength: 40,
            style: GoogleFonts.inter(fontSize: 15),
            decoration: _fieldDeco('e.g. The north is ours.'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏴', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Upload your flag', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('This image will appear on every territory you capture on the map.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3, height: 1.4)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickFlag,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _flagFile != null ? AppTheme.accent : AppTheme.t4,
                  width: 2,
                ),
              ),
              child: _flagFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_flagFile!, fit: BoxFit.cover, width: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.image_outlined, color: AppTheme.accent, size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text('Choose from gallery', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.t2)),
                        const SizedBox(height: 4),
                        Text('PNG, JPG · Recommended 3:2', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _tip(Icons.star_outline, 'Use your country\'s flag or custom artwork'),
          const SizedBox(height: 8),
          _tip(Icons.map_outlined, 'Tiles across your territory like a real map'),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎨', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Pick accent color', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Used for your clan border on the map and badges.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3)),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: _colors.map((c) {
              final isSelected = c == _selectedColor;
              final hex = c.replaceAll('#', '');
              final color = Color(int.parse('FF$hex', radix: 16));
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? AppTheme.t1 : Colors.transparent, width: 3),
                    boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)] : [],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Open membership', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Anyone can join without approval', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                    ],
                  ),
                ),
                Switch(value: _isOpen, onChanged: (v) => setState(() => _isOpen = v), activeColor: AppTheme.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    final nameText = _nameController.text.trim().isEmpty ? 'Your Clan' : _nameController.text.trim();
    final sloganText = _sloganController.text.trim().isEmpty ? 'Your slogan here...' : _sloganController.text.trim();
    final hex = _selectedColor.replaceAll('#', '');
    final color = Color(int.parse('FF$hex', radix: 16));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Looking good!', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Here\'s how your clan will appear to others.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.t3)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0F0F18), borderRadius: BorderRadius.circular(20)),
            child: Stack(
              children: [
                Positioned(
                  top: -30, right: -30,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [color.withOpacity(0.3), Colors.transparent]),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_flagFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_flagFile!, width: 72, height: 48, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 72, height: 48,
                        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.shield_rounded, color: color, size: 28),
                      ),
                    const SizedBox(height: 14),
                    Text(nameText, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(sloganText, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.45), fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _previewTag('Street Crew', AppTheme.gold),
                        const SizedBox(width: 6),
                        _previewTag(_isOpen ? 'Open' : 'Invite Only', Colors.white.withOpacity(0.2)),
                        const SizedBox(width: 6),
                        _previewTag('1 member', Colors.white.withOpacity(0.2)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color == Colors.white.withOpacity(0.2) ? Colors.white70 : color)),
    );
  }

  Widget _inputLabel(String text) {
    return Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.t3, letterSpacing: 0.5));
  }

  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppTheme.t4),
      filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.accent, width: 2)),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.tips_and_updates_outlined, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.t2, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
