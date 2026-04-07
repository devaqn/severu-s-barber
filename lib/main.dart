import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/atendimento_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/cliente_controller.dart';
import 'controllers/estoque_controller.dart';
import 'screens/admin/barbeiros_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/agenda/agenda_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/atendimentos/atendimentos_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/primeiro_login_screen.dart';
import 'screens/barbeiro/barbeiro_dashboard_screen.dart';
import 'screens/caixa/caixa_screen.dart';
import 'screens/clientes/clientes_screen.dart';
import 'screens/comanda/abrir_comanda_screen.dart';
import 'screens/comanda/comandas_screen.dart';
import 'screens/estoque/estoque_screen.dart';
import 'screens/financeiro/financeiro_screen.dart';
import 'screens/produtos/produtos_screen.dart';
import 'screens/ranking/ranking_screen.dart';
import 'screens/relatorios/relatorios_screen.dart';
import 'screens/servicos/servicos_screen.dart';
import 'utils/app_theme.dart';
import 'firebase_options.dart';

final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (details) {
    return const Material(
      color: Color(0xFF202124),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Ocorreu um erro ao iniciar esta tela.\nReinicie o app e tente novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  };

  await _inicializarFirebase();

  runApp(const SeverusBarberApp());
}

Future<void> _inicializarFirebase() async {
  try {
    final isAndroidOrIos = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isAndroidOrIos) {
      // Android/iOS usam configuracao nativa (google-services / plist).
      await Firebase.initializeApp();
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase nao inicializado. Rodando em modo offline. Erro: $e');
  }
}

class SeverusBarberApp extends StatelessWidget {
  const SeverusBarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ClienteController()),
        ChangeNotifierProvider(create: (_) => AtendimentoController()),
        ChangeNotifierProvider(create: (_) => EstoqueController()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, _) {
          return MaterialApp(
            title: 'Severus Barber',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (ctx, child) => MediaQuery(
              data: (() {
                final media = MediaQuery.of(ctx);
                final scale =
                    media.textScaler.scale(1).clamp(0.9, 1.2).toDouble();
                return media.copyWith(textScaler: TextScaler.linear(scale));
              })(),
              child: child!,
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/primeiro-login': (_) =>
                  const ProtectedRoute(child: PrimeiroLoginScreen()),
              '/dashboard-admin': (_) => const ProtectedRoute(
                    adminOnly: true,
                    child: AdminDashboardScreen(),
                  ),
              '/dashboard-barbeiro': (_) =>
                  const ProtectedRoute(child: BarbeiroDashboardScreen()),
              '/clientes': (_) => const ProtectedRoute(child: ClientesScreen()),
              '/admin/barbeiros': (_) => const ProtectedRoute(
                  adminOnly: true, child: BarbeirosScreen()),
              '/servicos': (_) => const ProtectedRoute(
                  adminOnly: true, child: ServicosScreen()),
              '/produtos': (_) => const ProtectedRoute(
                  adminOnly: true, child: ProdutosScreen()),
              '/atendimentos': (_) =>
                  const ProtectedRoute(child: AtendimentosScreen()),
              '/agenda': (_) => const ProtectedRoute(child: AgendaScreen()),
              '/financeiro': (_) => const ProtectedRoute(
                  adminOnly: true, child: FinanceiroScreen()),
              '/estoque': (_) =>
                  const ProtectedRoute(adminOnly: true, child: EstoqueScreen()),
              '/caixa': (_) =>
                  const ProtectedRoute(adminOnly: true, child: CaixaScreen()),
              '/analytics': (_) => const ProtectedRoute(
                  adminOnly: true, child: AnalyticsScreen()),
              '/ranking': (_) =>
                  const ProtectedRoute(adminOnly: true, child: RankingScreen()),
              '/relatorios': (_) => const ProtectedRoute(
                  adminOnly: true, child: RelatoriosScreen()),
              '/comandas': (_) => const ProtectedRoute(child: ComandasScreen()),
              '/comandas/nova': (_) =>
                  const ProtectedRoute(child: AbrirComandaScreen()),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().inicializar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.verificando:
        return const AuthLoadingScreen();
      case AuthStatus.autenticadoAdmin:
        if (auth.usuario?.firstLogin ?? false) {
          return const PrimeiroLoginScreen();
        }
        return const AdminDashboardScreen();
      case AuthStatus.autenticadoBarbeiro:
        if (auth.usuario?.firstLogin ?? false) {
          return const PrimeiroLoginScreen();
        }
        return const BarbeiroDashboardScreen();
      case AuthStatus.naoAutenticado:
        return const LoginScreen();
    }
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.content_cut, color: AppTheme.accentColor, size: 60),
            SizedBox(height: 20),
            CircularProgressIndicator(color: AppTheme.accentColor),
          ],
        ),
      ),
    );
  }
}

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final bool adminOnly;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.adminOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.status == AuthStatus.verificando) {
      return const AuthLoadingScreen();
    }

    if (auth.status == AuthStatus.naoAutenticado) {
      return const LoginScreen();
    }

    if (adminOnly && !auth.isAdmin) {
      return const AccessDeniedScreen();
    }

    return child;
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final homeRoute = auth.isAdmin ? '/dashboard-admin' : '/dashboard-barbeiro';

    return Scaffold(
      appBar: AppBar(title: const Text('Acesso negado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 54, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              const Text(
                'Seu perfil nao tem permissao para acessar esta tela.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                      context, homeRoute, (route) => false);
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Voltar ao dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
