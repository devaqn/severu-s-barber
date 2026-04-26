import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfilePhotoService {
  static const String _photosDirName = 'profile_photos';
  static const List<String> _extensions = ['.jpg', '.jpeg', '.png', '.webp'];
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  // Validates file content by checking magic bytes instead of trusting path extension.
  // JPEG: FF D8 FF | PNG: 89 50 4E 47 | WebP: RIFF....WEBP
  static bool _isValidImageBytes(Uint8List header) {
    if (header.length < 4) return false;
    if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      return true; // JPEG
    }
    if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      return true; // PNG
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return true; // WebP
    }
    return false;
  }

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

    final size = await source.length();
    if (size > _maxFileSizeBytes) {
      throw Exception('Imagem muito grande. Tamanho máximo: 10 MB.');
    }

    final raf = await source.open();
    final headerBytes = await raf.read(12);
    await raf.close();
    if (!_isValidImageBytes(headerBytes)) {
      throw Exception(
        'Formato de imagem inválido. Use JPEG, PNG ou WebP.',
      );
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
