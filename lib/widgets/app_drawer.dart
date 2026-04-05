// ============================================================
// app_drawer.dart
// Main side menu with role-based navigation.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../main.dart' show themeModeNotifier;
import '../utils/app_theme.dart';

class AppDrawer extends StatelessWidget {
  static const String dashboard = 'dashboard';
  static const String atendimentos = 'atendimentos';
  static const String comandas = 'comandas';
  static const String agenda = 'agenda';
  static const String clientes = 'clientes';
  static const String barbeiros = 'barbeiros';
  static const String servicos = 'servicos';
  static const String produtos = 'produtos';
  static const String estoque = 'estoque';
  static const String financeiro = 'financeiro';
  static const String caixa = 'caixa';
  static const String analytics = 'analytics';
  static const String ranking = 'ranking';
  static const String relatorios = 'relatorios';

  final String? selectedItem;

  const AppDrawer({super.key, this.selectedItem});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isAdmin = auth.isAdmin;

    return Drawer(
      backgroundColor: AppTheme.primaryColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentColor, AppTheme.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.textPrimary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'SB',
                      style: GoogleFonts.poppins(
                        color: AppTheme.goldColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Severus Barber',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAdmin ? 'Perfil: Dono/Admin' : 'Perfil: Funcionário',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.usuarioNome.isEmpty ? 'Sessão ativa' : auth.usuarioNome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                _DrawerItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  color: AppTheme.accentColor,
                  isActive: selectedItem == dashboard,
                  onTap: () => _goDashboard(context),
                ),
                const _DrawerSection(title: 'Atendimento'),
                _DrawerItem(
                  icon: Icons.receipt_long,
                  label: 'Comandas',
                  color: AppTheme.accentColor,
                  isActive: selectedItem == comandas,
                  onTap: () =>
                      _navigateTo(context, '/comandas', AppDrawer.comandas),
                ),
                _DrawerItem(
                  icon: Icons.content_cut,
                  label: 'Atendimentos',
                  color: AppTheme.purpleStart,
                  isActive: selectedItem == atendimentos,
                  onTap: () => _navigateTo(
                      context, '/atendimentos', AppDrawer.atendimentos),
                ),
                _DrawerItem(
                  icon: Icons.event,
                  label: 'Agenda',
                  color: AppTheme.infoColor,
                  isActive: selectedItem == agenda,
                  onTap: () =>
                      _navigateTo(context, '/agenda', AppDrawer.agenda),
                ),
                const _DrawerSection(title: 'Cadastros'),
                _DrawerItem(
                  icon: Icons.people,
                  label: 'Clientes',
                  color: AppTheme.infoColor,
                  isActive: selectedItem == clientes,
                  onTap: () =>
                      _navigateTo(context, '/clientes', AppDrawer.clientes),
                ),
                if (isAdmin) ...[
                  _DrawerItem(
                    icon: Icons.badge_outlined,
                    label: 'Adicionar Barbeiro',
                    color: AppTheme.goldColor,
                    isActive: selectedItem == barbeiros,
                    onTap: () => _navigateTo(
                      context,
                      '/admin/barbeiros',
                      AppDrawer.barbeiros,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.design_services,
                    label: 'ServiÃ§os',
                    color: AppTheme.warningColor,
                    isActive: selectedItem == servicos,
                    onTap: () =>
                        _navigateTo(context, '/servicos', AppDrawer.servicos),
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_bag,
                    label: 'Produtos',
                    color: AppTheme.successColor,
                    isActive: selectedItem == produtos,
                    onTap: () =>
                        _navigateTo(context, '/produtos', AppDrawer.produtos),
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_2,
                    label: 'Estoque',
                    color: AppTheme.warningColor,
                    isActive: selectedItem == estoque,
                    onTap: () =>
                        _navigateTo(context, '/estoque', AppDrawer.estoque),
                  ),
                  const _DrawerSection(title: 'Financeiro'),
                  _DrawerItem(
                    icon: Icons.attach_money,
                    label: 'Financeiro',
                    color: AppTheme.goldColor,
                    isActive: selectedItem == financeiro,
                    onTap: () => _navigateTo(
                        context, '/financeiro', AppDrawer.financeiro),
                  ),
                  _DrawerItem(
                    icon: Icons.point_of_sale,
                    label: 'Caixa',
                    color: AppTheme.successColor,
                    isActive: selectedItem == caixa,
                    onTap: () =>
                        _navigateTo(context, '/caixa', AppDrawer.caixa),
                  ),
                  const _DrawerSection(title: 'Analises'),
                  _DrawerItem(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    color: AppTheme.infoColor,
                    isActive: selectedItem == analytics,
                    onTap: () =>
                        _navigateTo(context, '/analytics', AppDrawer.analytics),
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events,
                    label: 'Ranking de Clientes',
                    color: AppTheme.goldColor,
                    isActive: selectedItem == ranking,
                    onTap: () =>
                        _navigateTo(context, '/ranking', AppDrawer.ranking),
                  ),
                  _DrawerItem(
                    icon: Icons.summarize,
                    label: 'RelatÃ³rios',
                    color: AppTheme.errorColor,
                    isActive: selectedItem == relatorios,
                    onTap: () => _navigateTo(
                        context, '/relatorios', AppDrawer.relatorios),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.9)),
              ),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (ctx, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return Row(
                      children: [
                        Icon(
                          dark ? Icons.dark_mode : Icons.light_mode,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modo Escuro',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: dark,
                          activeThumbColor: AppTheme.accentColor,
                          onChanged: (v) {
                            themeModeNotifier.value =
                                v ? ThemeMode.dark : ThemeMode.light;
                          },
                        ),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Severus Barber v2.0.0',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _confirmarLogout(context),
                    icon: const Icon(Icons.logout,
                        color: AppTheme.errorColor, size: 18),
                    label: Text(
                      'Sair',
                      style: GoogleFonts.inter(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goDashboard(BuildContext context) {
    final auth = context.read<AuthController>();
    final route = auth.isAdmin ? '/dashboard-admin' : '/dashboard-barbeiro';
    _navigateTo(context, route, AppDrawer.dashboard);
  }

  void _navigateTo(BuildContext context, String route, String key) {
    Navigator.pop(context);
    if (selectedItem == key) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  void _confirmarLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sair',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: const Text('Deseja realmente sair do sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthController>().logout();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;

  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentColor.withValues(alpha: 0.15)
            : AppTheme.primaryColor.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? const Border(
                left: BorderSide(color: AppTheme.accentColor, width: 3))
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

