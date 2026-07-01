import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/feed/providers/feed_provider.dart';
import 'package:turf_app/core/utils/image_crop_utils.dart';
import 'dart:io';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final List<File> _imageFiles = [];
  String _type = 'regular';
  bool _loading = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageFiles.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Maximum 3 photos per post'),
        backgroundColor: AppTheme.t2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final file = await ImageCropUtils.pickAndCrop(
      ratio: CropRatio.post,
      toolbarTitle: 'Crop Photo',
    );
    if (file != null) setState(() => _imageFiles.add(file));
  }

  Future<void> _post() async {
    if (_contentController.text.trim().isEmpty && _imageFiles.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(feedNotifierProvider.notifier).createPost(
        content: _contentController.text.trim(),
        type: _type,
        imageFile: _imageFiles.isNotEmpty ? _imageFiles.first : null,
        imageFiles: _imageFiles,
      );
      if (mounted) Navigator.pop(context);
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
          // ── HEADER ──
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.white,
              border: Border(bottom: BorderSide(color: AppTheme.sep)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppTheme.bg, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.t1),
                  ),
                ),
                const SizedBox(width: 12),
                Text('New Post',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : _post,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accent2]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: _loading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Post',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── TYPE CHIPS ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _typeChip('regular', Icons.edit_rounded, 'Regular'),
                          const SizedBox(width: 8),
                          _typeChip('capture', Icons.map_outlined, 'Capture'),
                          const SizedBox(width: 8),
                          _typeChip('achievement', Icons.emoji_events_rounded, 'Achievement'),
                        ],
                      ),
                    ),
                  ),

                  // ── TEXT INPUT ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _contentController,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 300,
                      style: GoogleFonts.inter(fontSize: 16, color: AppTheme.t1, height: 1.5),
                      decoration: InputDecoration(
                        hintText: "What's happening in your territory?",
                        hintStyle: GoogleFonts.inter(color: AppTheme.t3, fontSize: 15),
                        border: InputBorder.none,
                        counterStyle: GoogleFonts.inter(fontSize: 11, color: AppTheme.t3),
                        filled: true,
                        fillColor: AppTheme.bg,
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // ── PHOTOS SECTION ──
                  if (_imageFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Carousel
                    SizedBox(
                      height: 260,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            itemCount: _imageFiles.length,
                            itemBuilder: (_, i) => Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_imageFiles[i], fit: BoxFit.cover),
                                // Remove button
                                Positioned(
                                  top: 10, right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _imageFiles.removeAt(i);
                                        if (_currentPage >= _imageFiles.length && _currentPage > 0) {
                                          _currentPage--;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                                // Photo counter badge
                                Positioned(
                                  top: 10, left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('${i + 1} / ${_imageFiles.length}',
                                        style: GoogleFonts.inter(
                                            fontSize: 11, fontWeight: FontWeight.w600,
                                            color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Dot indicators
                          if (_imageFiles.length > 1)
                            Positioned(
                              bottom: 10,
                              left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_imageFiles.length, (i) =>
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: _currentPage == i ? 18 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: _currentPage == i
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ── ADD PHOTO BUTTON (если меньше 3 фото) ──
                  if (_imageFiles.length < 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: _imageFiles.isEmpty ? 120 : 54,
                          decoration: BoxDecoration(
                            color: AppTheme.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: _imageFiles.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded,
                                          color: AppTheme.accent, size: 22),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Add photos (up to 3)',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accent)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded,
                                        color: AppTheme.accent, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Add another photo (${_imageFiles.length}/3)',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accent)),
                                  ],
                                ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.t1 : AppTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.t1 : AppTheme.sep,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: isSelected ? Colors.white : AppTheme.t2),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.t2)),
          ],
        ),
      ),
    );
  }
}
