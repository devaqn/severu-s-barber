// ============================================================
// auth_service.dart
// Authentication service with Firebase Auth + Firestore.
// Includes offline fallback only when secure credentials are
// provided via --dart-define.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';

class AuthService {
  AuthService();

  final DatabaseHelper _db = DatabaseHelper();
  static Usuario? _usuarioLocalLogado;

  // Default offline credentials for UI/design testing.
  // Use --dart-define to override in real environments.
  static const String _offlineAdminEmailDefine = String.fromEnvironment(
    'OFFLINE_ADMIN_EMAIL',
    defaultValue: 'admin@offline.test',
  );
  static const String _offlineAdminPasswordDefine = String.fromEnvironment(
    'OFFLINE_ADMIN_PASSWORD',
    defaultValue: '123456',
  );
  static const String _provisioningAppName = 'severus_provisioning';

  bool get _firebaseDisponivel => Firebase.apps.isNotEmpty;

  bool get _offlineDisponivel =>
      _offlineAdminEmailDefine.trim().isNotEmpty &&
      _offlineAdminPasswordDefine.trim().isNotEmpty;

  FirebaseAuth get _auth {
    _garantirFirebaseInicializado();
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    _garantirFirebaseInicializado();
    return FirebaseFirestore.instance;
  }

  // ---------------------------------------------------------------------------
  // Estado do usuario
  // ---------------------------------------------------------------------------

  Stream<User?> get authStateChanges => _firebaseDisponivel
      ? _auth.authStateChanges()
      : const Stream<User?>.empty();

  User? get currentUser => _firebaseDisponivel ? _auth.currentUser : null;

  Future<Usuario?> getCurrentUsuario() async {
    if (!_firebaseDisponivel) return _usuarioLocalLogado;
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUsuarioPorId(user.uid);
  }

  // ---------------------------------------------------------------------------
  // Autenticacao
  // ---------------------------------------------------------------------------

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

      final usuario = await getUsuarioPorId(credential.user!.uid);
      if (usuario == null) {
        throw Exception(
          'Conta autenticada sem perfil no sistema. Contate o administrador.',
        );
      }
      if (!usuario.ativo) {
        await _auth.signOut();
        throw Exception('Usuario inativo. Contate o administrador.');
      }

      return usuario;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    }
  }

  Future<Usuario> cadastrarBarbeiro({
    required String nome,
    required String email,
    required String password,
    double comissaoPercentual = 0.50,
  }) async {
    _garantirFirebaseInicializado();
    await _assertAdminSession();

    final sanitizedNome = SecurityUtils.sanitizeName(nome, fieldName: 'Nome');
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);
    SecurityUtils.ensureStrongPassword(password);
    final sanitizedComissao = SecurityUtils.sanitizeDoubleRange(
      comissaoPercentual,
      fieldName: 'Comissao',
      min: 0.0,
      max: 1.0,
    );

    try {
      final provisioningAuth = await _getProvisioningAuth();
      final credential = await provisioningAuth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );
      await credential.user!.updateDisplayName(sanitizedNome);

      final usuario = Usuario(
        id: credential.user!.uid,
        nome: sanitizedNome,
        email: sanitizedEmail,
        role: AppConstants.roleBarbeiro,
        ativo: true,
        comissaoPercentual: sanitizedComissao,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.tableUsuarios)
          .doc(usuario.id)
          .set(usuario.toFirestore());

      await provisioningAuth.signOut();
      return usuario;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErroAuth(e);
    }
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

    try {
      final credential = existeAdmin
          ? await (await _getProvisioningAuth()).createUserWithEmailAndPassword(
              email: sanitizedEmail,
              password: password,
            )
          : await _auth.createUserWithEmailAndPassword(
              email: sanitizedEmail,
              password: password,
            );

      await credential.user!.updateDisplayName(sanitizedNome);

      final usuario = Usuario(
        id: credential.user!.uid,
        nome: sanitizedNome,
        email: sanitizedEmail,
        role: AppConstants.roleAdmin,
        ativo: true,
        comissaoPercentual: 0.0,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.tableUsuarios)
          .doc(usuario.id)
          .set(usuario.toFirestore());

      if (existeAdmin) {
        final provisioningAuth = await _getProvisioningAuth();
        await provisioningAuth.signOut();
      }

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
  }

  Future<void> recuperarSenha(String email) async {
    _garantirFirebaseInicializado();
    final sanitizedEmail = SecurityUtils.sanitizeEmail(email);

    try {
      await _auth.sendPasswordResetEmail(email: sanitizedEmail);
    } on FirebaseAuthException catch (e) {
      // Evita enumeracao de contas.
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

  // ---------------------------------------------------------------------------
  // Gestao de usuarios (Firestore)
  // ---------------------------------------------------------------------------

  Future<Usuario?> getUsuarioPorId(String id) async {
    if (!_firebaseDisponivel) return null;
    final sanitizedId =
        SecurityUtils.sanitizeIdentifier(id, fieldName: 'ID do usuario');
    final doc = await _firestore
        .collection(AppConstants.tableUsuarios)
        .doc(sanitizedId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return Usuario.fromFirestore(doc.data()!);
  }

  Future<List<Usuario>> listarUsuarios() async {
    _garantirFirebaseInicializado();
    await _assertAdminSession();

    final snap = await _firestore
        .collection(AppConstants.tableUsuarios)
        .orderBy('nome')
        .get();
    return snap.docs.map((d) => Usuario.fromFirestore(d.data())).toList();
  }

  Future<List<Usuario>> listarBarbeiros({bool apenasAtivos = true}) async {
    if (!_firebaseDisponivel) return <Usuario>[];
    if (_auth.currentUser == null) {
      throw Exception('Autenticacao obrigatoria.');
    }

    Query query = _firestore
        .collection(AppConstants.tableUsuarios)
        .where('role', isEqualTo: AppConstants.roleBarbeiro);

    if (apenasAtivos) {
      query = query.where('ativo', isEqualTo: true);
    }

    final snap = await query.orderBy('nome').get();
    return snap.docs
        .map((d) => Usuario.fromFirestore(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> atualizarUsuario(Usuario usuario) async {
    _garantirFirebaseInicializado();
    await _assertAdminSession();

    final sanitizedNome =
        SecurityUtils.sanitizeName(usuario.nome, fieldName: 'Nome');
    final sanitizedEmail = SecurityUtils.sanitizeEmail(usuario.email);
    final sanitizedRole = SecurityUtils.sanitizeEnumValue(
      usuario.role,
      fieldName: 'Perfil',
      allowedValues: const [AppConstants.roleAdmin, AppConstants.roleBarbeiro],
    );
    final sanitizedComissao = SecurityUtils.sanitizeDoubleRange(
      usuario.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0.0,
      max: 1.0,
    );

    final safeUsuario = usuario.copyWith(
      nome: sanitizedNome,
      email: sanitizedEmail,
      role: sanitizedRole,
      comissaoPercentual: sanitizedComissao,
    );

    await _firestore
        .collection(AppConstants.tableUsuarios)
        .doc(safeUsuario.id)
        .update(safeUsuario.toFirestore());
  }

  Future<void> toggleAtivo(String userId, bool ativo) async {
    _garantirFirebaseInicializado();
    await _assertAdminSession();

    final sanitizedId =
        SecurityUtils.sanitizeIdentifier(userId, fieldName: 'ID do usuario');
    await _firestore
        .collection(AppConstants.tableUsuarios)
        .doc(sanitizedId)
        .update({'ativo': ativo});
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Exception _traduzirErroAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Email ou senha invalidos.');
      case 'email-already-in-use':
        return Exception('Este email ja esta em uso.');
      case 'weak-password':
        return Exception('Senha fraca. Use uma senha mais forte.');
      case 'invalid-email':
        return Exception('Email invalido.');
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
      throw Exception('Firebase nao inicializado.');
    }
  }

  Future<bool> _hasAnyAdmin() async {
    final snap = await _firestore
        .collection(AppConstants.tableUsuarios)
        .where('role', isEqualTo: AppConstants.roleAdmin)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _assertAdminSession() async {
    final usuario = await getCurrentUsuario();
    if (usuario == null || !usuario.ativo || !usuario.isAdmin) {
      throw Exception('Apenas administradores podem executar esta acao.');
    }
  }

  Future<FirebaseAuth> _getProvisioningAuth() async {
    _garantirFirebaseInicializado();
    FirebaseApp app;
    try {
      app = Firebase.app(_provisioningAppName);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: _provisioningAppName,
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<Usuario> _loginOffline({
    required String email,
    required String password,
  }) async {
    if (!_offlineDisponivel) {
      throw Exception(
        'Modo offline bloqueado por seguranca. Configure OFFLINE_ADMIN_EMAIL '
        'e OFFLINE_ADMIN_PASSWORD via --dart-define.',
      );
    }

    final offlineEmail = SecurityUtils.sanitizeEmail(_offlineAdminEmailDefine);
    const offlinePassword = _offlineAdminPasswordDefine;

    if (email != offlineEmail || password != offlinePassword) {
      throw Exception('Credenciais invalidas.');
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
            role: AppConstants.roleAdmin,
            ativo: true,
            comissaoPercentual: 0.0,
            createdAt: DateTime.now(),
          );

    if (!usuario.ativo || !usuario.isAdmin) {
      throw Exception(
          'Usuario offline inativo ou sem permissao administrativa.');
    }

    _usuarioLocalLogado = usuario;
    return usuario;
  }
}
