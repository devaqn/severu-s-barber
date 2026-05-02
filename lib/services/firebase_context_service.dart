import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'session_manager.dart';

class FirebaseContextService {
  FirebaseContextService({SessionManager? sessionManager})
      : _sessionManager = sessionManager ?? SessionManager();

  final SessionManager _sessionManager;

  bool get firebaseDisponivel {
    if (Firebase.apps.isEmpty) return false;
    final options = Firebase.app().options;
    return _firebaseConfigValida(options);
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<String?> getBarbeariaIdAtual({bool forceRefresh = false}) async {
    if (!firebaseDisponivel) return null;

    final cached = _sessionManager.barbeariaId;
    if (!forceRefresh && cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    final user = _auth.currentUser;
    if (user == null) return null;

    final resolved = await _sessionManager.getBarbeariaId(
      user.uid,
      forceRefresh: forceRefresh,
    );
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
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

  void setCachedBarbeariaId(String? value) {
    _sessionManager.setBarbeariaIdForCurrentUser(value);
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
