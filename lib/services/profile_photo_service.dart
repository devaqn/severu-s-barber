import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfilePhotoService {
  static const String _photosDirName = 'profile_photos';
  static const List<String> _extensions = ['.jpg', '.jpeg', '.png', '.webp'];

  Future<File?> getProfilePhoto(String userId) async {
    final safeId = _safeUserId(userId);
    if (safeId.isEmpty) return null;

    final dir = await _ensurePhotosDir();
    for (final ext in _extensions) {
      final candidate = File(p.join(dir.path, '$safeId$ext'));
      if (await candidate.exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<File> saveProfilePhoto({
    required String userId,
    required String sourcePath,
  }) async {
    final safeId = _safeUserId(userId);
    if (safeId.isEmpty) {
      throw Exception('Usuário inválido para salvar foto.');
    }

    final dir = await _ensurePhotosDir();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Arquivo de imagem não encontrado.');
    }

    var ext = p.extension(source.path).toLowerCase();
    if (!_extensions.contains(ext)) {
      ext = '.jpg';
    }

    final target = File(p.join(dir.path, '$safeId$ext'));

    // Remove variantes anteriores para manter apenas uma foto por usuario.
    for (final existingExt in _extensions) {
      final old = File(p.join(dir.path, '$safeId$existingExt'));
      if (await old.exists() && old.path != target.path) {
        await old.delete();
      }
    }

    return source.copy(target.path);
  }

  Future<void> deleteProfilePhoto(String userId) async {
    final safeId = _safeUserId(userId);
    if (safeId.isEmpty) return;

    final dir = await _ensurePhotosDir();
    for (final ext in _extensions) {
      final file = File(p.join(dir.path, '$safeId$ext'));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Directory> _ensurePhotosDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, _photosDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeUserId(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.@:-]'), '_');
  }
}
