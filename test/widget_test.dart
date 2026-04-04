import 'package:barbearia_pro/controllers/auth_controller.dart';
import 'package:barbearia_pro/main.dart';
import 'package:barbearia_pro/models/usuario.dart';
import 'package:barbearia_pro/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Usuario buildUsuario({required bool isAdmin}) {
    return Usuario(
      id: isAdmin ? 'admin-1' : 'barbeiro-1',
      nome: isAdmin ? 'Dono Teste' : 'Funcionário Teste',
      email: isAdmin ? 'dono@teste.com' : 'funcionario@teste.com',
      role: isAdmin ? 'admin' : 'barbeiro',
      ativo: true,
      comissaoPercentual: isAdmin ? 0.0 : 0.5,
      createdAt: DateTime(2026, 3, 18),
    );
  }

  testWidgets('App deve inicializar sem erro critico',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SeverusBarberApp());
    await tester.pump();

    expect(find.byType(SeverusBarberApp), findsOneWidget);
  });

  testWidgets('Fluxo dono: drawer identifica perfil admin',
      (WidgetTester tester) async {
    final auth = AuthController();
    auth.debugSetSessao(buildUsuario(isAdmin: true));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(
          home: AppDrawer(selectedItem: AppDrawer.dashboard),
        ),
      ),
    );

    expect(
        find.text('Perfil: Dono/Admin', skipOffstage: false), findsOneWidget);
    expect(find.text('Comandas', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Fluxo funcionário: drawer identifica perfil de funcionário',
      (WidgetTester tester) async {
    final auth = AuthController();
    auth.debugSetSessao(buildUsuario(isAdmin: false));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(
          home: AppDrawer(selectedItem: AppDrawer.dashboard),
        ),
      ),
    );

    expect(
        find.text('Perfil: Funcionário', skipOffstage: false), findsOneWidget);
    expect(find.text('Comandas', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Fluxo funcionario: rota admin fica bloqueada',
      (WidgetTester tester) async {
    final auth = AuthController();
    auth.debugSetSessao(buildUsuario(isAdmin: false));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          initialRoute: '/admin',
          routes: {
            '/admin': (_) => const ProtectedRoute(
                  adminOnly: true,
                  child: Scaffold(body: Text('Area Admin')),
                ),
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);
    expect(find.text('Area Admin'), findsNothing);
  });

  testWidgets('Fluxo dono: rota admin libera acesso',
      (WidgetTester tester) async {
    final auth = AuthController();
    auth.debugSetSessao(buildUsuario(isAdmin: true));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          initialRoute: '/admin',
          routes: {
            '/admin': (_) => const ProtectedRoute(
                  adminOnly: true,
                  child: Scaffold(body: Text('Area Admin')),
                ),
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Area Admin'), findsOneWidget);
    expect(find.text('Acesso negado'), findsNothing);
  });
}
