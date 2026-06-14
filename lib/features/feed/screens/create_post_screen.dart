import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/feed/providers/feed_provider.dart';
import 'dart:io';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  File? _imageFile;
  String _type = 'regular';
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _post() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(feedNotifierProvider.notifier).createPost(
        content: _contentController.text.trim(),
        type: _type,
        imageFile: _imageFile,
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
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: Text('New Post', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _loading ? null : _post,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Post', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _typeChip('regular', 'Regular'),
                  const SizedBox(width: 8),
                  _typeChip('capture', '🗺️ Capture'),
                  const SizedBox(width: 8),
                  // War posts are auto-generated
                  const SizedBox(width: 8),
                  _typeChip('achievement', '🏆 Achievement'),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.sep),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                style: GoogleFonts.inter(fontSize: 16, color: AppTheme.t1),
                decoration: InputDecoration(
                  hintText: 'What\'s happening in your territory?',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(color: AppTheme.t3, fontSize: 16),
                ),
              ),
            ),
          ),
          if (_imageFile != null)
            Stack(
              children: [
                ClipRRect(
                  child: Image.file(_imageFile!, width: double.infinity, height: 200, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageFile = null),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.sep))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.image_outlined, color: AppTheme.accent, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_on_outlined, color: AppTheme.t3, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.t1 : AppTheme.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.t2)),
      ),
    );
  }
}
