import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ImageUpload {
  static Future<String?> upload(File file, String folder) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id ?? 'anonymous';
      final fileName = '$folder/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('media').upload(fileName, file);
      return supabase.storage.from('media').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }
}
