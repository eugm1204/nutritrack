import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  final SupabaseClient _client;
  static const _avatarsBucket = 'avatars';

  ProfileRepository(this._client);

  Future<Profile> getOrCreate(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (row == null) {
      final inserted = await _client.from('profiles').insert({'id': userId}).select().single();
      return Profile.fromJson(inserted);
    }
    return Profile.fromJson(row);
  }

  Future<Profile> update(String userId, Profile profile) async {
    final row = await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(row);
  }

  Future<String> uploadAvatar(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    final ext = p.extension(file.name).isEmpty ? '.jpg' : p.extension(file.name);
    final path = '$userId/avatar$ext';

    await _client.storage.from(_avatarsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.mimeType ?? 'image/jpeg',
            upsert: true,
          ),
        );

    return _client.storage.from(_avatarsBucket).getPublicUrl(path);
  }
}