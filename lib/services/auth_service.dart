// ============================================================
// auth_service.dart
// Authentication service with Firebase Auth + Firestore
// (multi-tenant by barbearia) and SQLite offline fallback.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'firebase_context_service.dart';

class AuthService {
  AuthService({
    DatabaseHelper? db,
    FirebaseContextService? context,
  })  : _db = db ?? DatabaseHelper(),
        _context = context ?? FirebaseContextService();

  final DatabaseHelper _db;
  final FirebaseContextService _context;

  Usuario? _usuarioLocalLogado;

  static const bool _offlineLoginEnabledDefine = bool.fromEnvironment(
    'ENABLE_OFFLINE_LOGIN',
    defaultValue: false,
  );
  static const bool _firebaseTestShortcutEnabledDefine = bool.fromEnvironment(
    'ENABLE_FIREBASE_TEST_SHORTCUT',
    defaultValue: false,
  );

  static const String _offlineAdminEmailDefine = String.fromEnvironment(
    'OFFLINE_ADMIN_EMAIL',
    defaultValue: '',
  );
  static const String _offlineAdminPasswordDefine = String.fromEnvironment(
    'OFFLINE_ADMIN_PASSWORD',
    defaultValue: '',
  );
  static const String _firebaseTestAdminNameDefine = String.fromEnvironment(
    'FIREBASE_TEST_ADMIN_NAME',
    defaultValue: '',
  );
  static const String _firebaseTestAdminEmailDefine = String.fromEnvironment(
    'FIREBASE_TEST_ADMIN_EMAIL',
    defaultValue: '',
  );
  static const String _firebaseTestAdminPasswordDefine = String.fromEnvironment(
    'FIREBASE_TEST_ADMIN_PASSWORD',
    defaultValue: '',
  );

  bool get _firebaseDisponivel {
    if (Firebase.apps.isEmpty) return false;
    final options = Firebase.app().options;
    return _firebaseConfigValida(options);
  }

  bool get firebaseDisponivel => _firebaseDisponivel;

  bool get _offlineLoginEnabled => _offlineLoginEnabledDefine || !kReleaseMode;

  bool get _offlineDisponivel =>
      _offlineLoginEnabled &&
      _offlineAdminEmailDefine.trim().isNotEmpty &&
      _offlineAdminPasswordDefine.trim().isNotEmpty;

  bool get _firebaseTestCredenciaisDefinidas =>
      _firebaseTestAdminNameDefine.trim().isNotEmpty &&
      _firebaseTestAdminEmailDefine.trim().isNotEmpty &&
      _firebaseTestAdminPasswordDefine.trim().isNotEmpty;

  bool get firebaseTestShortcutDisponivel =>
      !kReleaseMode &&
      _firebaseTestShortcutEnabledDefine &&
      _firebaseTestCredenciaisDefinidas;

  FirebaseAuth get _auth {
    _garantirFirebaseInicializado();
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    _garantirFirebaseInicializado();
    return FirebaseFirestore.instance;
  }

  Stream<User?> get authStateChanges => _firebaseDisponivel
      ? _auth.authStateChanges()
      : const Stream<User?>.empty();

  User? get currentUser => _firebaseDisponivel ? _auth.currentUser : null;

  Future<Usuario?> getCurrentUsuario() async {
    if (!_firebaseDisponivel) return _usuarioLocalLogado;

    final user = _auth.currentUser;
    if (user == null) return _usuarioLocalLogado;

    final remoto = await _buscarUsuarioFirestore(user.uid);
    if (remoto != null) {
      await _upsertUsuarioLocal(remoto);
      FirebaseContextService.setCachedBarbeariaId(remoto.barbeariaId);
      _usuarioLocalLogado = remoto;
      return remoto;
    }

    final local = await _getUsuarioLocalPorId(user.uid);
    _usuarioLocalLogado = local;
    return local;
  }

  Future<Usuario> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = SecurityUtils.sanitizeEmail(email);
    SecurityUtils.ensure(password.isNotEmpty, 'Senha obrigatoria.');

    if (!_firebaseDisponivel) {
      return _loginOffline(
        email: normalizedEmail,
        password: password,
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final usuario = await _buscarUsuarioFirestore(credential.user!.uid);
      if (usuario == null) {
        throw Exception(
          'Conta autenticada sem perfil no sistema. Contate o administrador.',
        );
      }
      if (!usuario.ativo) {
        await _auth.signOut();
        throw Exception('Usuario inativo. Contate o administrador.');
      }

      await _upsertUsuarioLocal(usuario);
      FirebaseContextService.setCachedBarbeariaId(usuario.barbeariaId);
      _usuarioLocalLogado = usuario;
      return usuario;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    }
  }

  Future<Usuario> entrarOuCriarContaTesteFirebase() async {
    if (kReleaseMode || !_firebaseTestShortcutEnabledDefine) {
      throw Exception('Atalho de conta de teste desativado nesta versao.');
    }
    if (!_firebaseTestCredenciaisDefinidas) {
      throw Exception(
        'Conta de teste nao configurada. '
        'Defina FIREBASE_TEST_ADMIN_NAME, FIREBASE_TEST_ADMIN_EMAIL '
        'e FIREBASE_TEST_ADMIN_PASSWORD via --dart-define.',
      );
    }

    final email = SecurityUtils.sanitizeEmail(_firebaseTestAdminEmailDefine);
    const senha = _firebaseTestAdminPasswordDefine;
    final nome = SecurityUtils.sanitizeName(
      _firebaseTestAdminNameDefine,
      fieldName: 'Nome da conta teste',
    );
    SecurityUtils.ensureStrongPassword(senha);

    if (!_firebaseDisponivel) {
      return _loginOffline(email: email, password: senha);
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final usuario = await _garantirPerfilAdminParaUser(
        user: cred.user!,
        nome: nome,
        email: email,
      );
      _usuarioLocalLogado = usuario;
      FirebaseContextService.setCachedBarbeariaId(usuario.barbeariaId);
      return usuario;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' &&
          e.code != 'wrong-password' &&
          e.code != 'invalid-credential' &&
          e.code != 'invalid-login-credentials') {
        throw _traduzirErroAuth(e);
      }
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final usuario = await _garantirPerfilAdminParaUser(
        user: cred.user!,
        nome: nome,
        email: email,
      );
      _usuarioLocalLogado = usuario;
      FirebaseContextService.setCachedBarbeariaId(usuario.barbeariaId);
      return usuario;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final cred = await _auth.signInWithEmailAndPassword(
            email: email,
            password: senha,
          );
          final usuario = await _garantirPerfilAdminParaUser(
            user: cred.user!,
            nome: nome,
            email: email,
          );
          _usuarioLocalLogado = usuario;
          FirebaseContextService.setCachedBarbeariaId(usuario.barbeariaId);
          return usuario;
        } on FirebaseAuthException {
          throw Exception(
            'Conta de teste ja existe com outra senha. '
            'Atualize FIREBASE_TEST_ADMIN_PASSWORD.',
          );
        }
      }
      throw _traduzirErroAuth(e);
    }
  }

  Future<UserCredential> criarContaBarbeiro({
    required String email,
    required String senha,
    required String nome,
    String? telefone,
    required double comissaoPercentual,
  }) async {
    _garantirFirebaseInicializado();
    final admin = await _assertAdminSession();

    final sanitizedNome = SecurityUtils.sanitizeName(nome, fieldName: 'Nome');
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);
    SecurityUtils.ensureStrongPassword(senha);
    final sanitizedTelefone = SecurityUtils.sanitizeOptionalPhone(telefone);
    final sanitizedComissao = SecurityUtils.sanitizeDoubleRange(
      comissaoPercentual,
      fieldName: 'Comissao',
      min: 0,
      max: 100,
    );

    final shopId = _resolveBarbeariaId(admin);

    SecurityUtils.ensure(
      !(await _emailEmUso(sanitizedEmail)),
      'E-mail ja cadastrado.',
    );

    final secondaryApp = await Firebase.initializeApp(
      name: 'secondaryApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: senha,
      );

      await _ensureBarbeariaDocument(shopId, admin.id);

      await _usuariosCollection(shopId).doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'id': credential.user!.uid,
        'nome': sanitizedNome,
        'email': sanitizedEmail,
        'telefone': sanitizedTelefone,
        'photo_url': null,
        'role': AppConstants.roleBarbeiro,
        'comissao_percentual': sanitizedComissao,
        'first_login': true,
        'ativo': true,
        'barbearia_id': shopId,
        'created_by': admin.id,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final usuario = Usuario(
        id: credential.user!.uid,
        nome: sanitizedNome,
        email: sanitizedEmail,
        telefone: sanitizedTelefone,
        photoUrl: null,
        role: UserRole.barbeiro,
        ativo: true,
        comissaoPercentual: sanitizedComissao,
        firstLogin: true,
        barbeariaId: shopId,
        createdAt: DateTime.now(),
      );
      await _upsertUsuarioLocal(usuario);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      try {
        await secondaryApp.delete();
      } catch (_) {}
    }
  }

  Future<Usuario> cadastrarBarbeiro({
    required String nome,
    required String email,
    required String password,
    String? telefone,
    double comissaoPercentual = 50.0,
    bool firstLogin = true,
  }) async {
    final safeTelefone = SecurityUtils.sanitizeOptionalPhone(telefone);

    final cred = await criarContaBarbeiro(
      email: email,
      senha: password,
      nome: nome,
      telefone: safeTelefone,
      comissaoPercentual: comissaoPercentual,
    );

    final usuario = await _buscarUsuarioFirestore(cred.user!.uid);
    if (usuario == null) {
      throw Exception('Conta criada sem perfil no Firestore.');
    }

    if (!firstLogin && usuario.firstLogin) {
      await _usuariosCollection(_resolveBarbeariaId(usuario))
          .doc(usuario.id)
          .update({
        'first_login': false,
        'updated_at': FieldValue.serverTimestamp()
      });
      final atualizado = usuario.copyWith(firstLogin: false);
      await _upsertUsuarioLocal(atualizado);
      return atualizado;
    }

    return usuario;
  }

  Future<Usuario> cadastrarAdmin({
    required String nome,
    required String email,
    required String password,
  }) async {
    _garantirFirebaseInicializado();

    final sanitizedNome = SecurityUtils.sanitizeName(nome, fieldName: 'Nome');
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);
    SecurityUtils.ensureStrongPassword(password);

    final existeAdmin = await _hasAnyAdmin();
    if (existeAdmin) {
      await _assertAdminSession();
    }

    SecurityUtils.ensure(
      !(await _emailEmUso(sanitizedEmail)),
      'E-mail ja cadastrado.',
    );

    try {
      UserCredential credential;
      if (existeAdmin) {
        final app = await Firebase.initializeApp(
          name: 'secondaryApp_admin_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final secondaryAuth = FirebaseAuth.instanceFor(app: app);
        try {
          credential = await secondaryAuth.createUserWithEmailAndPassword(
            email: sanitizedEmail,
            password: password,
          );
        } finally {
          try {
            await secondaryAuth.signOut();
          } catch (_) {}
          try {
            await app.delete();
          } catch (_) {}
        }
      } else {
        credential = await _auth.createUserWithEmailAndPassword(
          email: sanitizedEmail,
          password: password,
        );
      }

      final shopId = existeAdmin
          ? _resolveBarbeariaId(await _assertAdminSession())
          : 'shop_${credential.user!.uid}';

      await _ensureBarbeariaDocument(shopId, credential.user!.uid);

      await _usuariosCollection(shopId).doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'id': credential.user!.uid,
        'nome': sanitizedNome,
        'email': sanitizedEmail,
        'telefone': null,
        'photo_url': null,
        'role': AppConstants.roleAdmin,
        'ativo': true,
        'comissao_percentual': 0.0,
        'first_login': false,
        'barbearia_id': shopId,
        'created_by': credential.user!.uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final usuario = Usuario(
        id: credential.user!.uid,
        nome: sanitizedNome,
        email: sanitizedEmail,
        telefone: null,
        photoUrl: null,
        role: UserRole.admin,
        ativo: true,
        comissaoPercentual: 0.0,
        firstLogin: false,
        barbeariaId: shopId,
        createdAt: DateTime.now(),
      );
      await _upsertUsuarioLocal(usuario);
      FirebaseContextService.setCachedBarbeariaId(shopId);
      _usuarioLocalLogado = usuario;
      return usuario;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    }
  }

  Future<void> logout() async {
    if (_firebaseDisponivel) {
      await _auth.signOut();
    }
    _usuarioLocalLogado = null;
    FirebaseContextService.setCachedBarbeariaId(null);
  }

  Future<void> recuperarSenha(String email) async {
    _garantirFirebaseInicializado();
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);

    try {
      await _auth.sendPasswordResetEmail(email: sanitizedEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return;
      }
      throw _traduzirErroAuth(e);
    }
  }

  Future<void> alterarSenha(String novaSenha) async {
    _garantirFirebaseInicializado();
    SecurityUtils.ensureStrongPassword(novaSenha);

    try {
      await _auth.currentUser?.updatePassword(novaSenha);
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    }
  }

  Future<void> concluirPrimeiroLogin() async {
    String? userId;
    if (_firebaseDisponivel) {
      userId = _auth.currentUser?.uid;
    } else {
      userId = _usuarioLocalLogado?.id;
    }
    if (userId == null || userId.trim().isEmpty) {
      await _marcarPrimeiroLoginConcluidoLocal();
      return;
    }

    if (!_firebaseDisponivel) {
      await _marcarPrimeiroLoginConcluidoLocal(userId: userId);
      return;
    }

    final perfil = await _buscarUsuarioFirestore(userId);
    if (perfil == null) {
      await _marcarPrimeiroLoginConcluidoLocal(userId: userId);
      return;
    }

    final shopId = _resolveBarbeariaId(perfil);
    await _usuariosCollection(shopId).doc(userId).update({
      'first_login': false,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final atualizado = perfil.copyWith(firstLogin: false);
    await _upsertUsuarioLocal(atualizado);
    _usuarioLocalLogado = atualizado;
  }

  Future<Usuario> atualizarFotoPerfil(String? photoUrl) async {
    final usuarioAtual = await getCurrentUsuario();
    if (usuarioAtual == null) {
      throw Exception('Usuário não autenticado.');
    }

    final safePhotoUrl = SecurityUtils.sanitizeOptionalText(
      photoUrl,
      maxLength: 2048,
      allowNewLines: false,
    );
    final shopId = _resolveBarbeariaId(usuarioAtual);

    if (_firebaseDisponivel) {
      await _usuariosCollection(shopId).doc(usuarioAtual.id).set({
        'photo_url': safePhotoUrl,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final atualizado = usuarioAtual.copyWith(
      photoUrl: safePhotoUrl,
      barbeariaId: shopId,
    );
    await _upsertUsuarioLocal(atualizado);

    if (_usuarioLocalLogado?.id == atualizado.id) {
      _usuarioLocalLogado = atualizado;
    }

    return atualizado;
  }

  Future<Usuario?> getUsuarioPorId(String id) async {
    final sanitizedId =
        SecurityUtils.sanitizeIdentifier(id, fieldName: 'ID do usuario');

    if (!_firebaseDisponivel) {
      return _getUsuarioLocalPorId(sanitizedId);
    }

    final remoto = await _buscarUsuarioFirestore(sanitizedId);
    if (remoto != null) {
      await _upsertUsuarioLocal(remoto);
      return remoto;
    }

    return _getUsuarioLocalPorId(sanitizedId);
  }

  Future<List<Usuario>> listarUsuarios() async {
    final admin = await _assertAdminSession();

    if (!_firebaseDisponivel) {
      return _listarUsuariosLocais();
    }

    final shopId = _resolveBarbeariaId(admin);
    final snap = await _usuariosCollection(shopId).orderBy('nome').get();
    final usuarios = snap.docs.map((d) {
      final data = <String, dynamic>{...d.data()};
      data['id'] = data['id'] ?? d.id;
      data['uid'] = data['uid'] ?? d.id;
      data['barbearia_id'] = data['barbearia_id'] ?? shopId;
      data['created_at'] = _normalizeDateValue(data['created_at']);
      return Usuario.fromFirestore(data);
    }).toList(growable: false);

    await _syncUsuariosLocais(usuarios);
    return usuarios;
  }

  Future<List<Usuario>> listarBarbeiros({bool apenasAtivos = true}) async {
    if (!_firebaseDisponivel) {
      final usuarios = await _listarUsuariosLocais();
      return usuarios
          .where((u) => u.isBarbeiro && (!apenasAtivos || u.ativo))
          .toList(growable: false);
    }

    final atual = await getCurrentUsuario();
    if (atual == null) {
      throw Exception('Autenticacao obrigatoria.');
    }

    Query<Map<String, dynamic>> query = _usuariosCollection(
      _resolveBarbeariaId(atual),
    ).where('role', isEqualTo: AppConstants.roleBarbeiro);

    if (apenasAtivos) {
      query = query.where('ativo', isEqualTo: true);
    }

    final snap = await query.orderBy('nome').get();
    final usuarios = snap.docs.map((d) {
      final data = <String, dynamic>{...d.data()};
      data['id'] = data['id'] ?? d.id;
      data['uid'] = data['uid'] ?? d.id;
      data['barbearia_id'] = data['barbearia_id'] ?? _resolveBarbeariaId(atual);
      data['created_at'] = _normalizeDateValue(data['created_at']);
      return Usuario.fromFirestore(data);
    }).toList(growable: false);

    await _syncUsuariosLocais(usuarios);
    return usuarios;
  }

  Future<void> atualizarUsuario(Usuario usuario) async {
    final admin = await _assertAdminSession();

    final sanitizedNome =
        SecurityUtils.sanitizeName(usuario.nome, fieldName: 'Nome');
    final sanitizedEmail = SecurityUtils.sanitizeEmail(usuario.email);
    final sanitizedTelefone = SecurityUtils.sanitizeOptionalPhone(
      usuario.telefone,
    );
    final sanitizedPhotoUrl = SecurityUtils.sanitizeOptionalText(
      usuario.photoUrl,
      maxLength: 2048,
      allowNewLines: false,
    );
    final sanitizedRole = SecurityUtils.sanitizeEnumValue(
      usuario.role.value,
      fieldName: 'Perfil',
      allowedValues: const [AppConstants.roleAdmin, AppConstants.roleBarbeiro],
    );
    final sanitizedComissao = SecurityUtils.sanitizeDoubleRange(
      usuario.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0.0,
      max: 100.0,
    );

    final shopId = _resolveBarbeariaId(admin);

    final safeUsuario = usuario.copyWith(
      nome: sanitizedNome,
      email: sanitizedEmail,
      telefone: sanitizedTelefone,
      photoUrl: sanitizedPhotoUrl,
      role: UserRole.fromString(sanitizedRole),
      comissaoPercentual: sanitizedComissao,
      barbeariaId: shopId,
    );

    if (_firebaseDisponivel) {
      await _usuariosCollection(shopId).doc(safeUsuario.id).set({
        ...safeUsuario.toFirestore(),
        'uid': safeUsuario.id,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _upsertUsuarioLocal(safeUsuario);
  }

  Future<void> toggleAtivo(String userId, bool ativo) async {
    final admin = await _assertAdminSession();

    final sanitizedId =
        SecurityUtils.sanitizeIdentifier(userId, fieldName: 'ID do usuario');
    final shopId = _resolveBarbeariaId(admin);

    if (_firebaseDisponivel) {
      await _usuariosCollection(shopId).doc(sanitizedId).update({
        'ativo': ativo,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    final local = await _getUsuarioLocalPorId(sanitizedId);
    if (local != null) {
      await _upsertUsuarioLocal(local.copyWith(ativo: ativo));
    }
  }

  Future<void> excluirBarbeiro(String userId) async {
    final admin = await _assertAdminSession();
    final sanitizedId =
        SecurityUtils.sanitizeIdentifier(userId, fieldName: 'ID do usuario');
    final shopId = _resolveBarbeariaId(admin);

    SecurityUtils.ensure(
      sanitizedId != admin.id,
      'Nao e permitido excluir o usuario administrador atual.',
    );

    if (_firebaseDisponivel) {
      await _usuariosCollection(shopId).doc(sanitizedId).delete();
    }

    await _db.delete(
      AppConstants.tableUsuarios,
      'id = ?',
      [sanitizedId],
    );
  }

  Future<bool> podeCadastrarAdminPublicamente() async {
    if (!_firebaseDisponivel) {
      return false;
    }
    return !(await _hasAnyAdmin());
  }

  Exception _traduzirErroAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return Exception('E-mail ou senha inválidos.');
      case 'email-already-in-use':
        return Exception('E-mail ja cadastrado.');
      case 'weak-password':
        return Exception('Senha fraca. Use uma senha mais forte.');
      case 'invalid-email':
        return Exception('E-mail inválido.');
      case 'operation-not-allowed':
        return Exception(
          'Login por e-mail/senha não está habilitado no Firebase Authentication.',
        );
      case 'app-not-authorized':
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return Exception(
          'Configuracao do Firebase inválida. Verifique google-services.json.',
        );
      case 'too-many-requests':
        return Exception('Muitas tentativas. Tente novamente mais tarde.');
      case 'network-request-failed':
        return Exception('Sem conexao com a internet.');
      case 'requires-recent-login':
        return Exception('Reautentique-se para concluir esta operacao.');
      default:
        return Exception('Erro de autenticacao. Tente novamente.');
    }
  }

  void _garantirFirebaseInicializado() {
    if (!_firebaseDisponivel) {
      throw Exception(
        'Firebase não configurado neste app. '
        'Use google-services.json real para autenticar online.',
      );
    }
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

  Future<bool> _hasAnyAdmin() async {
    if (_firebaseDisponivel) {
      try {
        final snap = await _firestore
            .collectionGroup(AppConstants.tableUsuarios)
            .where('role', isEqualTo: AppConstants.roleAdmin)
            .limit(1)
            .get();
        return snap.docs.isNotEmpty;
      } on FirebaseException catch (e) {
        // Em regras de producao fechadas, usuario deslogado pode nao ter
        // permissao de leitura para esse collectionGroup.
        if (e.code == 'permission-denied') {
          return false;
        }
        rethrow;
      }
    }

    final rows = await _db.rawQuery('''
      SELECT COUNT(*) as total
      FROM ${AppConstants.tableUsuarios}
      WHERE role = ?
    ''', [AppConstants.roleAdmin]);
    final total = (rows.first['total'] as num?)?.toInt() ?? 0;
    return total > 0;
  }

  Future<bool> _emailEmUso(String email) async {
    final normalized = SecurityUtils.sanitizeEmail(email);

    if (_firebaseDisponivel) {
      final firestoreRows = await _firestore
          .collectionGroup(AppConstants.tableUsuarios)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (firestoreRows.docs.isNotEmpty) {
        return true;
      }
    }

    final localRows = await _db.queryAll(
      AppConstants.tableUsuarios,
      where: 'email = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    return localRows.isNotEmpty;
  }

  Future<Usuario> _assertAdminSession() async {
    final usuario = await getCurrentUsuario();
    if (usuario == null || !usuario.ativo || !usuario.isAdmin) {
      throw Exception('Apenas administradores podem executar esta acao.');
    }
    return usuario;
  }

  String _resolveBarbeariaId(Usuario usuario) {
    final id = usuario.barbeariaId;
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }
    return AppConstants.localBarbeariaId;
  }

  CollectionReference<Map<String, dynamic>> _usuariosCollection(
    String barbeariaId,
  ) {
    return _context.collection(
      barbeariaId: barbeariaId,
      nome: AppConstants.tableUsuarios,
    );
  }

  Future<void> _ensureBarbeariaDocument(
      String shopId, String uidCriador) async {
    await _context.barbeariaDoc(shopId).set({
      'id': shopId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by': uidCriador,
    }, SetOptions(merge: true));
  }

  Future<Usuario> _garantirPerfilAdminParaUser({
    required User user,
    required String nome,
    required String email,
  }) async {
    final existente = await _buscarUsuarioFirestore(user.uid);
    if (existente != null) {
      await _upsertUsuarioLocal(existente);
      return existente;
    }

    final shopId = 'shop_${user.uid}';
    await _ensureBarbeariaDocument(shopId, user.uid);
    await _usuariosCollection(shopId).doc(user.uid).set({
      'uid': user.uid,
      'id': user.uid,
      'nome': nome,
      'email': email,
      'telefone': null,
      'photo_url': null,
      'role': AppConstants.roleAdmin,
      'ativo': true,
      'comissao_percentual': 0.0,
      'first_login': false,
      'barbearia_id': shopId,
      'created_by': user.uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final criado = Usuario(
      id: user.uid,
      nome: nome,
      email: email,
      telefone: null,
      photoUrl: null,
      role: UserRole.admin,
      ativo: true,
      comissaoPercentual: 0.0,
      firstLogin: false,
      barbeariaId: shopId,
      createdAt: DateTime.now(),
    );
    await _upsertUsuarioLocal(criado);
    return criado;
  }

  Future<Usuario?> _buscarUsuarioFirestore(String uid) async {
    if (!_firebaseDisponivel) return null;

    final cachedShop = await _context.getBarbeariaIdAtual();
    if (cachedShop != null && cachedShop.trim().isNotEmpty) {
      final doc = await _usuariosCollection(cachedShop).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = <String, dynamic>{...doc.data()!};
        data['id'] = data['id'] ?? uid;
        data['uid'] = data['uid'] ?? uid;
        data['barbearia_id'] = data['barbearia_id'] ?? cachedShop;
        data['created_at'] = _normalizeDateValue(data['created_at']);
        return Usuario.fromFirestore(data);
      }
    }

    final group = await _firestore
        .collectionGroup(AppConstants.tableUsuarios)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (group.docs.isNotEmpty) {
      final doc = group.docs.first;
      final data = <String, dynamic>{...doc.data()};
      final shopId = (data['barbearia_id'] as String?) ??
          doc.reference.parent.parent?.id ??
          AppConstants.localBarbeariaId;
      data['id'] = data['id'] ?? uid;
      data['uid'] = data['uid'] ?? uid;
      data['barbearia_id'] = shopId;
      data['created_at'] = _normalizeDateValue(data['created_at']);
      return Usuario.fromFirestore(data);
    }

    return null;
  }

  String _normalizeDateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return DateTime.now().toIso8601String();
  }

  Future<void> _syncUsuariosLocais(List<Usuario> usuarios) async {
    for (final usuario in usuarios) {
      await _upsertUsuarioLocal(usuario);
    }
  }

  Future<void> _upsertUsuarioLocal(Usuario usuario) async {
    await _db.insert(AppConstants.tableUsuarios, usuario.toMap());
  }

  Future<void> _marcarPrimeiroLoginConcluidoLocal({String? userId}) async {
    Usuario? base = _usuarioLocalLogado;
    if (base == null && userId != null && userId.trim().isNotEmpty) {
      base = await _getUsuarioLocalPorId(userId);
    }
    if (base == null) return;

    final atualizado = base.copyWith(firstLogin: false);
    await _upsertUsuarioLocal(atualizado);
    _usuarioLocalLogado = atualizado;
  }

  Future<Usuario?> _getUsuarioLocalPorId(String id) async {
    final rows = await _db.queryAll(
      AppConstants.tableUsuarios,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Usuario.fromMap(rows.first);
  }

  Future<List<Usuario>> _listarUsuariosLocais() async {
    final rows = await _db.queryAll(
      AppConstants.tableUsuarios,
      orderBy: 'nome ASC',
    );
    return rows.map((e) => Usuario.fromMap(e)).toList(growable: false);
  }

  Future<Usuario> _loginOffline({
    required String email,
    required String password,
  }) async {
    if (!_offlineLoginEnabled) {
      throw Exception('Modo offline desativado nesta versao.');
    }

    if (!_offlineDisponivel) {
      throw Exception(
        'Modo offline bloqueado por seguranca. Configure '
        'ENABLE_OFFLINE_LOGIN=true, OFFLINE_ADMIN_EMAIL e '
        'OFFLINE_ADMIN_PASSWORD via --dart-define.',
      );
    }

    final offlineEmail = SecurityUtils.sanitizeEmail(_offlineAdminEmailDefine);
    const offlinePassword = _offlineAdminPasswordDefine;

    if (email != offlineEmail || password != offlinePassword) {
      throw Exception('Credenciais inválidas para o modo offline.');
    }

    final rows = await _db.queryAll(
      AppConstants.tableUsuarios,
      where: 'email = ?',
      whereArgs: [offlineEmail],
      limit: 1,
    );

    final usuario = rows.isNotEmpty
        ? Usuario.fromMap(rows.first)
        : Usuario(
            id: 'admin_local',
            nome: 'Administrador',
            email: offlineEmail,
            role: UserRole.admin,
            ativo: true,
            comissaoPercentual: 0.0,
            firstLogin: false,
            barbeariaId: AppConstants.localBarbeariaId,
            createdAt: DateTime.now(),
          );

    if (!usuario.ativo || !usuario.isAdmin) {
      throw Exception(
          'Usuario offline inativo ou sem permissao administrativa.');
    }

    await _upsertUsuarioLocal(usuario);
    _usuarioLocalLogado = usuario;
    FirebaseContextService.setCachedBarbeariaId(usuario.barbeariaId);
    return usuario;
  }
}
