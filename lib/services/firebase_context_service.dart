import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../utils/constants.dart';

class FirebaseContextService {
  static String? _cachedBarbeariaId;

  bool get firebaseDisponivel {
    if (Firebase.apps.isEmpty) return false;
    final options = Firebase.app().options;
    return _firebaseConfigValida(options);
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<String?> getBarbeariaIdAtual({bool forceRefresh = false}) async {
    if (!firebaseDisponivel) return null;

    if (!forceRefresh &&
        _cachedBarbeariaId != null &&
        _cachedBarbeariaId!.trim().isNotEmpty) {
      return _cachedBarbeariaId;
    }

    final user = _auth.currentUser;
    if (user == null) return null;

    final resolved = await _resolverBarbeariaIdUsuario(user.uid);
    if (resolved != null && resolved.trim().isNotEmpty) {
      _cachedBarbeariaId = resolved;
      return resolved;
    }

    return null;
  }

  Future<String?> _resolverBarbeariaIdUsuario(String uid) async {
    final group = await _firestore
        .collectionGroup(AppConstants.tableUsuarios)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (group.docs.isNotEmpty) {
      final doc = group.docs.first;
      final data = doc.data();
      final byField = data['barbearia_id'] as String?;
      if (byField != null && byField.trim().isNotEmpty) {
        return byField;
      }
      final byPath = doc.reference.parent.parent?.id;
      if (byPath != null && byPath.trim().isNotEmpty) {
        return byPath;
      }
    }

    // Compatibilidade com estrutura legada /usuarios/{uid}
    final legacy =
        await _firestore.collection(AppConstants.tableUsuarios).doc(uid).get();
    if (legacy.exists && legacy.data() != null) {
      final byField = legacy.data()!['barbearia_id'] as String?;
      if (byField != null && byField.trim().isNotEmpty) {
        return byField;
      }
    }

    return null;
  }

  CollectionReference<Map<String, dynamic>> collection({
    required String barbeariaId,
    required String nome,
  }) {
    return _firestore
        .collection('barbearias')
        .doc(barbeariaId)
        .collection(nome);
  }

  DocumentReference<Map<String, dynamic>> barbeariaDoc(String barbeariaId) {
    return _firestore.collection('barbearias').doc(barbeariaId);
  }

  Map<String, dynamic> buildMetadata({
    required String barbeariaId,
    required String userId,
    bool includeCreatedAt = false,
  }) {
    return {
      'barbearia_id': barbeariaId,
      'created_by': userId,
      if (includeCreatedAt) 'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  static void setCachedBarbeariaId(String? value) {
    _cachedBarbeariaId = value;
  }

  bool _firebaseConfigValida(FirebaseOptions options) {
    final apiKey = options.apiKey.trim();
    final appId = options.appId.trim();
    final projectId = options.projectId.trim();
    final senderId = options.messagingSenderId.trim();

    if (_isLikelyPlaceholder(apiKey) ||
        _isLikelyPlaceholder(projectId) ||
        appId.isEmpty ||
        appId.contains(':000000000000:') ||
        appId.endsWith(':0000000000000000000000')) {
      return false;
    }

    if (senderId.isEmpty || RegExp(r'^0+$').hasMatch(senderId)) {
      return false;
    }

    return true;
  }

  bool _isLikelyPlaceholder(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return true;
    if (v.contains('placeholder')) return true;
    if (RegExp(r'^0+$').hasMatch(v)) return true;
    return false;
  }
}
