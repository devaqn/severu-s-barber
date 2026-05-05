// ============================================================
// auth_controller.dart
// Controller central de autenticação com ChangeNotifier.
// Mantém o estado do usuário logado e o tipo de acesso.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';

/// Estado de autenticação do aplicativo
enum AuthStatus {
  /// Verificando estado inicial (aguardando Firebase)
  verificando,

  /// Usuário não autenticado (mostra login)
  naoAutenticado,

  /// Usuário autenticado como Admin
  autenticadoAdmin,

  /// Usuário autenticado como Barbeiro
  autenticadoBarbeiro,
}

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  AuthStatus _status = AuthStatus.verificando;
  Usuario? _usuario;
  String? _errorMsg;
  bool _loading = false;

  // ── Getters públicos ──────────────────────────────────────────────

  AuthStatus get status => _status;
  Usuario? get usuario => _usuario;
  String? get errorMsg => _errorMsg;
  bool get isLoading => _loading;
  bool get isAdmin => _usuario?.isAdmin ?? false;
  bool get isBarbeiro => _usuario?.isBarbeiro ?? false;
  bool get firebaseDisponivel => _authService.firebaseDisponivel;
  bool get firebaseTestShortcutDisponivel =>
      _authService.firebaseTestShortcutDisponivel;
  String get usuarioId => _usuario?.id ?? '';
  String get usuarioNome => _usuario?.nome ?? '';
  String? get usuarioPhotoUrl => _usuario?.photoUrl;
  String get barbeariaId => _usuario?.barbeariaId ?? '';

  // ── Inicialização ─────────────────────────────────────────────────

  /// Inicializa o controller verificando o estado do Firebase Auth
  Future<void> inicializar() async {
    _status = AuthStatus.verificando;
    notifyListeners();
    try {
      // Tenta restaurar sessão anterior
      final u = await _authService
          .getCurrentUsuario()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (u != null) {
        _usuario = u;
        _status = u.isAdmin
            ? AuthStatus.autenticadoAdmin
            : AuthStatus.autenticadoBarbeiro;
      } else {
        _status = AuthStatus.naoAutenticado;
      }
    } catch (e, st) {
      debugPrint('AuthController.inicializar error: $e\n$st');
      _status = AuthStatus.naoAutenticado;
    }
    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────

  /// Realiza login e atualiza estado
  Future<bool> login(String email, String password) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final safeEmail = SecurityUtils.sanitizeEmail(email);
      SecurityUtils.ensure(password.isNotEmpty, 'Senha obrigatoria.');

      final u = await _authService.login(email: safeEmail, password: password);
      _usuario = u;
      _status = u.isAdmin
          ? AuthStatus.autenticadoAdmin
          : AuthStatus.autenticadoBarbeiro;
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.naoAutenticado;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> entrarOuCriarContaTesteFirebase() async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final u = await _authService.entrarOuCriarContaTesteFirebase();
      _usuario = u;
      _status = u.isAdmin
          ? AuthStatus.autenticadoAdmin
          : AuthStatus.autenticadoBarbeiro;
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.naoAutenticado;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> entrarSemLoginTemporario() async {
    // Only callable from debug builds — blocked in profile and release.
    if (!kDebugMode) {
      return false;
    }
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      _usuario = Usuario(
        id: 'admin_local',
        nome: 'Administrador (Teste)',
        email: 'teste@severus.app',
        role: UserRole.admin,
        ativo: true,
        comissaoPercentual: 0.0,
        firstLogin: false,
        barbeariaId: AppConstants.localBarbeariaId,
        createdAt: DateTime.now().toUtc(),
      );
      _status = AuthStatus.autenticadoAdmin;
      _authService.setCachedBarbeariaId(AppConstants.localBarbeariaId);
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.naoAutenticado;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Cadastro ──────────────────────────────────────────────────────

  /// Cadastra o primeiro administrador do sistema
  Future<bool> cadastrarAdmin({
    required String nome,
    required String email,
    required String password,
  }) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final safeNome = SecurityUtils.sanitizeName(nome, fieldName: 'Nome');
      final safeEmail = SecurityUtils.sanitizeEmail(email);
      SecurityUtils.ensureStrongPassword(password);

      final u = await _authService.cadastrarAdmin(
        nome: safeNome,
        email: safeEmail,
        password: password,
      );
      _usuario = u;
      _status = AuthStatus.autenticadoAdmin;
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Cadastra um novo barbeiro (apenas admin)
  Future<bool> cadastrarBarbeiro({
    required String nome,
    required String email,
    required String password,
    String? telefone,
    double comissaoPercentual = 50.0,
    bool firstLogin = true,
  }) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final safeNome = SecurityUtils.sanitizeName(nome, fieldName: 'Nome');
      final safeEmail = SecurityUtils.sanitizeEmail(email);
      SecurityUtils.ensureEmployeePassword(password);
      final safeComissao = SecurityUtils.sanitizeDoubleRange(
        comissaoPercentual,
        fieldName: 'Comissao',
        min: 0,
        max: 100,
      );

      await _authService.cadastrarBarbeiro(
        nome: safeNome,
        email: safeEmail,
        password: password,
        telefone: telefone,
        comissaoPercentual: safeComissao,
        firstLogin: firstLogin,
      );
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Logout e recuperação ──────────────────────────────────────────

  /// Desloga o usuário atual
  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _status = AuthStatus.naoAutenticado;
    notifyListeners();
  }

  /// Envia email de recuperação de senha
  Future<bool> recuperarSenha(String email) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      final safeEmail = SecurityUtils.sanitizeEmail(email);
      await _authService.recuperarSenha(safeEmail);
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> atualizarFotoPerfil(String? photoUrl) async {
    _errorMsg = null;
    try {
      final atualizado = await _authService.atualizarFotoPerfil(photoUrl);
      _usuario = atualizado;
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> podeCadastrarAdminPublicamente() {
    return _authService.podeCadastrarAdminPublicamente();
  }

  Future<List<Usuario>> listarBarbeiros({bool apenasAtivos = true}) async {
    _errorMsg = null;
    try {
      return await _authService.listarBarbeiros(apenasAtivos: apenasAtivos);
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return const <Usuario>[];
    }
  }

  Future<bool> concluirPrimeiroLoginComNovaSenha(String novaSenha) async {
    _loading = true;
    _errorMsg = null;
    notifyListeners();
    try {
      await _authService.alterarSenha(novaSenha);
      await _authService.concluirPrimeiroLogin();
      // Keep the in-memory user in sync so the screen doesn't need to call
      // setSessaoAposLogin manually.
      if (_usuario != null) {
        _usuario = _usuario!.copyWith(firstLogin: false);
      }
      return true;
    } catch (e) {
      _errorMsg = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Limpa mensagem de erro
  void limparErro() {
    _errorMsg = null;
    notifyListeners();
  }

  /// Atualiza o estado da sessão do usuário logado localmente.
  /// Usado por telas que precisam refletir alterações imediatas (ex:
  /// [PrimeiroLoginScreen]) sem aguardar uma nova chamada ao Firebase.
  void setSessaoAposLogin(Usuario? usuario) {
    _usuario = usuario;
    if (usuario == null) {
      _status = AuthStatus.naoAutenticado;
    } else if (usuario.isAdmin) {
      _status = AuthStatus.autenticadoAdmin;
    } else {
      _status = AuthStatus.autenticadoBarbeiro;
    }
    notifyListeners();
  }

  @visibleForTesting
  void debugSetSessao(Usuario? usuario) {
    _usuario = usuario;
    if (usuario == null) {
      _status = AuthStatus.naoAutenticado;
    } else if (usuario.isAdmin) {
      _status = AuthStatus.autenticadoAdmin;
    } else {
      _status = AuthStatus.autenticadoBarbeiro;
    }
    notifyListeners();
  }
}
