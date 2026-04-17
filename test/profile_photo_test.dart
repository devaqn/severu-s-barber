import 'package:barbearia_pro/controllers/auth_controller.dart';
import 'package:barbearia_pro/models/usuario.dart';
import 'package:barbearia_pro/services/auth_service.dart';
import 'package:barbearia_pro/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({required Usuario usuario}) : _usuarioAtual = usuario;

  Usuario _usuarioAtual;
  bool online = true;
  String? firestorePhotoUrl;
  String? sqlitePhotoUrl;
  String? pendingPhotoUrl;

  @override
  Future<Usuario?> getCurrentUsuario() async => _usuarioAtual;

  @override
  Future<Usuario> atualizarFotoPerfil(String? photoUrl) async {
    sqlitePhotoUrl = photoUrl;
    _usuarioAtual = _usuarioAtual.copyWith(photoUrl: photoUrl);

    if (!online) {
      pendingPhotoUrl = photoUrl;
      return _usuarioAtual;
    }

    firestorePhotoUrl = photoUrl;
    pendingPhotoUrl = null;
    return _usuarioAtual;
  }

  Future<void> sincronizarPendencias() async {
    if (!online || pendingPhotoUrl == null) return;
    firestorePhotoUrl = pendingPhotoUrl;
    pendingPhotoUrl = null;
  }
}

void main() {
  Usuario buildUsuario({String? photoUrl}) {
    return Usuario(
      id: 'barbeiro_1',
      nome: 'Joao Silva',
      email: 'joao@teste.com',
      role: UserRole.barbeiro,
      ativo: true,
      comissaoPercentual: 50.0,
      firstLogin: false,
      photoUrl: photoUrl,
      createdAt: DateTime(2026, 4, 5),
    );
  }

  test('Selecao de foto atualiza URL em Firestore e SQLite', () async {
    final fake = FakeAuthService(usuario: buildUsuario());
    final controller = AuthController(authService: fake);
    controller.debugSetSessao(buildUsuario());

    final ok = await controller.atualizarFotoPerfil('/tmp/perfil_1.jpg');

    expect(ok, isTrue);
    expect(fake.firestorePhotoUrl, '/tmp/perfil_1.jpg');
    expect(fake.sqlitePhotoUrl, '/tmp/perfil_1.jpg');
    expect(controller.usuarioPhotoUrl, '/tmp/perfil_1.jpg');
  });

  test('Troca de foto substitui URL anterior sem stale', () async {
    final fake =
        FakeAuthService(usuario: buildUsuario(photoUrl: '/tmp/old.jpg'));
    final controller = AuthController(authService: fake);
    controller.debugSetSessao(buildUsuario(photoUrl: '/tmp/old.jpg'));

    final ok = await controller.atualizarFotoPerfil('/tmp/new.jpg');

    expect(ok, isTrue);
    expect(fake.firestorePhotoUrl, '/tmp/new.jpg');
    expect(fake.sqlitePhotoUrl, '/tmp/new.jpg');
    expect(controller.usuarioPhotoUrl, '/tmp/new.jpg');
  });

  testWidgets('Remocao de foto persiste URL nula e drawer mostra placeholder S',
      (tester) async {
    final fake = FakeAuthService(usuario: buildUsuario(photoUrl: '/tmp/p.jpg'));
    final controller = AuthController(authService: fake);
    controller.debugSetSessao(buildUsuario(photoUrl: '/tmp/p.jpg'));

    final ok = await controller.atualizarFotoPerfil(null);
    expect(ok, isTrue);
    expect(fake.firestorePhotoUrl, isNull);
    expect(fake.sqlitePhotoUrl, isNull);
    expect(controller.usuarioPhotoUrl, isNull);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: const MaterialApp(
          home: AppDrawer(selectedItem: AppDrawer.dashboard),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('S'), findsOneWidget);
  });

  test('Offline salva local e sincroniza ao voltar online', () async {
    final fake = FakeAuthService(usuario: buildUsuario());
    final controller = AuthController(authService: fake);
    controller.debugSetSessao(buildUsuario());
    fake.online = false;

    final okOffline = await controller.atualizarFotoPerfil('/tmp/offline.jpg');

    expect(okOffline, isTrue);
    expect(fake.sqlitePhotoUrl, '/tmp/offline.jpg');
    expect(fake.firestorePhotoUrl, isNull);
    expect(fake.pendingPhotoUrl, '/tmp/offline.jpg');

    fake.online = true;
    await fake.sincronizarPendencias();

    expect(fake.pendingPhotoUrl, isNull);
    expect(fake.firestorePhotoUrl, '/tmp/offline.jpg');
  });
}
