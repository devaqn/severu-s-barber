import 'package:barbearia_pro/controllers/auth_controller.dart';
import 'package:barbearia_pro/models/usuario.dart';
import 'package:barbearia_pro/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.onLogin});

  final Future<Usuario> Function(String email, String password) onLogin;
  bool logoutCalled = false;

  @override
  Future<Usuario> login({
    required String email,
    required String password,
  }) {
    return onLogin(email, password);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<Usuario?> getCurrentUsuario() async => null;
}

Usuario _buildUsuario({required UserRole role}) {
  return Usuario(
    id: role == UserRole.admin ? 'admin_1' : 'barbeiro_1',
    nome: role == UserRole.admin ? 'Admin Teste' : 'Barbeiro Teste',
    email: role == UserRole.admin ? 'admin@teste.com' : 'barbeiro@teste.com',
    role: role,
    ativo: true,
    comissaoPercentual: role == UserRole.admin ? 0 : 50,
    firstLogin: false,
    createdAt: DateTime(2026, 4, 17),
  );
}

void main() {
  test('login com sucesso atualiza estado autenticado', () async {
    final fake = _FakeAuthService(
      onLogin: (_, __) async => _buildUsuario(role: UserRole.admin),
    );
    final controller = AuthController(authService: fake);

    final ok = await controller.login('admin@teste.com', 'Senha@123');

    expect(ok, isTrue);
    expect(controller.errorMsg, isNull);
    expect(controller.status, AuthStatus.autenticadoAdmin);
    expect(controller.usuario?.isAdmin, isTrue);
  });

  test('login inválido preenche errorMsg', () async {
    final fake = _FakeAuthService(
      onLogin: (_, __) async => throw Exception('Credenciais invalidas'),
    );
    final controller = AuthController(authService: fake);

    final ok = await controller.login('x@x.com', 'errada');

    expect(ok, isFalse);
    expect(controller.status, AuthStatus.naoAutenticado);
    expect(controller.errorMsg, contains('Credenciais invalidas'));
  });

  test('logout reseta estado local', () async {
    final fake = _FakeAuthService(
      onLogin: (_, __) async => _buildUsuario(role: UserRole.barbeiro),
    );
    final controller = AuthController(authService: fake);
    controller.debugSetSessao(_buildUsuario(role: UserRole.barbeiro));

    await controller.logout();

    expect(fake.logoutCalled, isTrue);
    expect(controller.usuario, isNull);
    expect(controller.status, AuthStatus.naoAutenticado);
  });
}
