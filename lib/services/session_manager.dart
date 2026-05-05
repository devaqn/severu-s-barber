import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';

class SessionState {
  const SessionState({required this.user, required this.barbeariaId});

  final User? user;
  final String? barbeariaId;

  bool get isAuthenticated => user != null && barbeariaId != null;
}

class SessionManager extends ChangeNotifier {
  SessionManager({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore {
    if (firebaseDisponivel) {
      _sub = _auth.authStateChanges().listen(_onAuthChanged);
      final current = _auth.currentUser;
      if (current != null) {
        unawaited(_onAuthChanged(current));
      }
    }
  }

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  StreamSubscription<User?>? _sub;

  String? _barbeariaId;
  User? _user;

  bool get firebaseDisponivel => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  String? get barbeariaId => _barbeariaId;
  User? get user => _user;
  SessionState get state =>
      SessionState(user: _user, barbeariaId: _barbeariaId);

  Stream<SessionState> authStateChanges() {
    if (!firebaseDisponivel) {
      return const Stream<SessionState>.empty();
    }
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        _user = null;
        _barbeariaId = null;
        return state;
      }
      final shopId = await getBarbeariaId(user.uid, forceRefresh: true);
      return SessionState(user: user, barbeariaId: shopId);
    });
  }

  Stream<T> shopStream<T>({
    required T signedOutValue,
    required Stream<T> Function(String barbeariaId, User user) builder,
  }) {
    if (!firebaseDisponivel) {
      return Stream<T>.value(signedOutValue);
    }
    return _auth.authStateChanges().asyncExpand((user) async* {
      if (user == null) {
        clear();
        yield signedOutValue;
        return;
      }
      final shopId = await getBarbeariaId(user.uid);
      if (shopId == null || shopId.trim().isEmpty) {
        yield signedOutValue;
        return;
      }
      yield* builder(shopId, user);
    });
  }

  Future<String?> getBarbeariaId(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (!firebaseDisponivel) return null;
    if (!forceRefresh &&
        _user?.uid == uid &&
        _barbeariaId != null &&
        _barbeariaId!.trim().isNotEmpty) {
      return _barbeariaId;
    }

    final resolved = await _resolveBarbeariaId(uid);
    _user = _auth.currentUser;
    _barbeariaId = resolved;
    notifyListeners();
    return resolved;
  }

  void setBarbeariaIdForCurrentUser(String? value) {
    _user = firebaseDisponivel ? _auth.currentUser : null;
    _barbeariaId = value;
    notifyListeners();
  }

  void clear() {
    _user = null;
    _barbeariaId = null;
    notifyListeners();
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      clear();
      return;
    }
    await getBarbeariaId(user.uid, forceRefresh: true);
  }

  Future<String?> _resolveBarbeariaId(String uid) async {
    try {
      final membership = await _firestore.collection('user_shops').doc(uid).get();
      final shopId = membership.data()?['barbearia_id'] as String?;
      if (shopId != null && shopId.trim().isNotEmpty) {
        return shopId;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    final deterministicShopId = 'shop_$uid';
    try {
      final deterministicUser = await _firestore
          .collection('barbearias')
          .doc(deterministicShopId)
          .collection(AppConstants.tableUsuarios)
          .doc(uid)
          .get();
      if (deterministicUser.exists) {
        return deterministicShopId;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    // Legacy fallback: resolved only while establishing the session, never per request.
    final QuerySnapshot<Map<String, dynamic>> legacy;
    try {
      legacy = await _firestore
          .collectionGroup(AppConstants.tableUsuarios)
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
    if (legacy.docs.isEmpty) return null;
    final doc = legacy.docs.first;
    final data = doc.data();
    return (data['barbearia_id'] as String?) ?? doc.reference.parent.parent?.id;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
