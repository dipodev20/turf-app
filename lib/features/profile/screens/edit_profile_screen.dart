import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turf_app/core/theme/app_theme.dart';
import 'package:turf_app/features/auth/providers/auth_provider.dart';
import 'dart:io';
import 'package:turf_app/core/utils/image_crop_utils.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  File? _avatarFile;
  File? _coverFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      _usernameController.text = user.username;
      _bioController.text = user.bio ?? '';
      _cityController.text = user.city ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImageCropUtils.pickAndCrop(
      ratio: CropRatio.square,
      toolbarTitle: 'Crop Avatar',
    );
    if (file == null) return;
    setState(() => _avatarFile = file);
  }

  Future<void> _pickCover() async {
    final file = await ImageCropUtils.pickAndCrop(
      ratio: CropRatio.banner,
      toolbarTitle: 'Crop Cover',
    );
    if (file == null) return;
    setState(() => _coverFile = file);
  }

  Future<String?> _uploadImage(File file, String folder) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final fileName = '$folder/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('media').upload(fileName, file);
    return supabase.storage.from('media').getPublicUrl(fileName);
  }

  Future<void> _save() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Username cannot be empty'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      String? avatarUrl;
      String? coverUrl;
      if (_avatarFile != null) avatarUrl = await _uploadImage(_avatarFile!, 'avatars');
      if (_coverFile != null) coverUrl = await _uploadImage(_coverFile!, 'covers');

      await ref.read(authNotifierProvider.notifier).updateProfile(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      }
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
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                  : Text('Save', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accent)),
            ),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          child: Column(
            children: [
              // Cover + Avatar
              Container(
                color: AppTheme.white,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: _pickCover,
                          child: Container(
                            height: 130,
                            width: double.infinity,
                            color: const Color(0xFF1C1C1E),
                            child: _coverFile != null
                                ? Image.file(_coverFile!, fit: BoxFit.cover, width: double.infinity)
                                : user?.coverUrl != null
                                    ? CachedNetworkImage(imageUrl: user!.coverUrl!, fit: BoxFit.cover)
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_outlined, color: Colors.white.withOpacity(0.3), size: 30),
                                            const SizedBox(height: 4),
                                            Text('Tap to change cover', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: -42,
                          left: 20,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 84, height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.white, width: 3),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                                  ),
                                  child: ClipOval(
                                    child: _avatarFile != null
                                        ? Image.file(_avatarFile!, fit: BoxFit.cover)
                                        : user?.avatarUrl != null
                                            ? CachedNetworkImage(imageUrl: user!.avatarUrl!, fit: BoxFit.cover)
                                            : Container(
                                                color: AppTheme.t1,
                                                child: Center(
                                                  child: Text(
                                                    user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : '?',
                                                    style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accent2]),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 56),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Form fields
              Container(
                color: AppTheme.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Username'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      maxLength: 20,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _deco('shadowwolf'),
                    ),
                    const SizedBox(height: 18),
                    _label('Bio'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 100,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _deco('Tell your story...'),
                    ),
                    const SizedBox(height: 4),
                    _label('City'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cityController,
                      maxLength: 30,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: _deco('Bishkek'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Share location
              Container(
                color: AppTheme.white,
                child: ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.location_on_outlined, color: AppTheme.accent, size: 18),
                  ),
                  title: Text('Share Live Location', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text('Others can see you on the map while running', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.t3)),
                  trailing: Switch(
                    value: user?.shareLocation ?? true,
                    activeColor: AppTheme.accent,
                    onChanged: (v) async {
                      final supabase = Supabase.instance.client;
                      final userId = supabase.auth.currentUser?.id;
                      if (userId != null) {
                        await supabase.from('users').update({'share_location': v}).eq('id', userId);
                        ref.invalidate(currentUserProvider);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 100),
          child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.t3, letterSpacing: 0.5));
  }

  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppTheme.t4),
      filled: true, fillColor: AppTheme.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.accent, width: 2)),
    );
  }
}
