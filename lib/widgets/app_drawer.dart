// ============================================================
// app_drawer.dart
// Main side menu with role-based navigation.
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../main.dart' show themeModeNotifier;
import '../services/profile_photo_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final ProfilePhotoService _photoService = ProfilePhotoService();
  final ImagePicker _picker = ImagePicker();

  String? _avatarPath;
  String? _avatarUserId;
  int _avatarVersion = 0;
  bool _updatingAvatar = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _drawerBg =>
      _isDarkMode ? AppTheme.primaryColor : AppTheme.lightCard;
  Color get _drawerSurface =>
      _isDarkMode ? AppTheme.secondaryColor : AppTheme.lightInputFill;
  Color get _drawerTextPrimary =>
      _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  Color get _drawerTextSecondary =>
      _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAvatar();
  }

  void _syncAvatar() {
    final auth = context.read<AuthController>();
    final userId = auth.usuarioId;
    final photoUrl = auth.usuarioPhotoUrl?.trim();

    if (userId.isEmpty) return;

    if (userId != _avatarUserId) {
      _avatarUserId = userId;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        setState(() {
          _avatarPath = photoUrl;
          _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        });
      } else {
        _loadAvatar(userId);
      }
      return;
    }

    if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != _avatarPath) {
      setState(() {
        _avatarPath = photoUrl;
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      });
      return;
    }

    if ((photoUrl == null || photoUrl.isEmpty) && _avatarPath == null) {
      _loadAvatar(userId);
    }
  }

  Future<void> _loadAvatar(String userId) async {
    final file = await _photoService.getProfilePhoto(userId);
    if (!mounted || _avatarUserId != userId) return;
    setState(() {
      _avatarPath = file?.path;
      _avatarVersion = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _invalidateAvatarCache(String? previousPath) async {
    final path = previousPath?.trim();
    if (path != null &&
        path.isNotEmpty &&
        !path.startsWith('http://') &&
        !path.startsWith('https://')) {
      await FileImage(File(path)).evict();
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void _showAvatarSnack(
    String mensagem, {
    bool isError = false,
  }) {
    final background = isError ? AppTheme.errorColor : AppTheme.accentColor;
    final foreground = isError ? AppTheme.textPrimary : AppTheme.primaryColor;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        content: Text(
          mensagem,
          style:
              GoogleFonts.inter(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _withCacheBust(String url) {
    if (_isDataImage(url)) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$_avatarVersion';
  }

  bool _isDataImage(String value) {
    return value.startsWith('data:image/') && value.contains(';base64,');
  }

  Uint8List? _decodeDataImage(String value) {
    try {
      final base64Part = value.substring(value.indexOf(';base64,') + 8);
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAvatarActions(AuthController auth) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _drawerSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppTheme.accentColor),
                title: Text(
                  'Tirar foto',
                  style: GoogleFonts.inter(color: _drawerTextPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickProfilePhoto(auth, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.accentColor),
                title: Text(
                  'Escolher da galeria',
                  style: GoogleFonts.inter(color: _drawerTextPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickProfilePhoto(auth, source: ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
                title: Text(
                  'Remover foto',
                  style: GoogleFonts.inter(color: _drawerTextPrimary),
                ),
                onTap: _avatarPath == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _removeProfilePhoto(auth);
                      },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickProfilePhoto(
    AuthController auth, {
    required ImageSource source,
  }) async {
    if (_updatingAvatar || auth.usuarioId.isEmpty) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (picked == null) return;

    final previousPath = _avatarPath;
    setState(() => _updatingAvatar = true);
    try {
      final photoUrl = await _photoService.saveProfilePhotoUrl(
        userId: auth.usuarioId,
        barbeariaId: auth.barbeariaId,
        sourcePath: picked.path,
      );
      final persisted = await auth.atualizarFotoPerfil(photoUrl);
      if (!persisted) {
        throw Exception(auth.errorMsg ?? 'Falha ao persistir foto de perfil.');
      }
      await _invalidateAvatarCache(previousPath);
      if (!mounted) return;
      setState(() {
        _avatarPath = photoUrl;
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      });
      _showAvatarSnack('Foto de perfil atualizada com sucesso.');
    } catch (_) {
      if (!mounted) return;
      _showAvatarSnack(
        'Nao foi possivel atualizar a foto de perfil.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingAvatar = false);
      }
    }
  }

  Future<void> _removeProfilePhoto(AuthController auth) async {
    if (_updatingAvatar || auth.usuarioId.isEmpty) return;

    final previousPath = _avatarPath;
    setState(() => _updatingAvatar = true);
    try {
      await _photoService.deleteProfilePhotoUrl(
        userId: auth.usuarioId,
        barbeariaId: auth.barbeariaId,
        photoUrl: previousPath,
      );
      final persisted = await auth.atualizarFotoPerfil(null);
      if (!persisted) {
        throw Exception(auth.errorMsg ?? 'Falha ao remover foto do perfil.');
      }
      await _invalidateAvatarCache(previousPath);
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      });
      _showAvatarSnack('Foto de perfil removida com sucesso.');
    } catch (_) {
      if (!mounted) return;
      _showAvatarSnack('Nao foi possivel remover a foto.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingAvatar = false);
      }
    }
  }

  Widget _buildHeader(AuthController auth, bool isAdmin) {
    final name = auth.usuarioNome.isEmpty ? 'Sessao ativa' : auth.usuarioNome;
    final path = _avatarPath?.trim();
    final isDataAvatar = path != null && _isDataImage(path);
    final avatarBytes = isDataAvatar ? _decodeDataImage(path) : null;
    final isNetworkAvatar = path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    final avatarFile =
        (!isNetworkAvatar && !isDataAvatar && path != null) ? File(path) : null;
    final hasAvatar = avatarBytes != null ||
        isNetworkAvatar ||
        (avatarFile?.existsSync() ?? false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/severusbanner.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: (_isDarkMode ? Colors.black : Colors.white)
              .withValues(alpha: _isDarkMode ? 0.48 : 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_isDarkMode ? Colors.white : AppTheme.accentDark)
                .withValues(alpha: _isDarkMode ? 0.22 : 0.26),
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: _updatingAvatar ? null : () => _openAvatarActions(auth),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: hasAvatar
                          ? avatarBytes != null
                              ? Image.memory(
                                  avatarBytes,
                                  key: ValueKey('data_avatar_$_avatarVersion'),
                                  fit: BoxFit.cover,
                                  width: 96,
                                  height: 96,
                                  errorBuilder: (_, __, ___) =>
                                      const _AvatarPlaceholder(),
                                )
                              : isNetworkAvatar
                                  ? Image.network(
                                      _withCacheBust(path),
                                      key: ValueKey(
                                          'network_avatar_${_withCacheBust(path)}'),
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                      errorBuilder: (_, __, ___) =>
                                          const _AvatarPlaceholder(),
                                    )
                                  : Image.file(
                                      avatarFile!,
                                      key: ValueKey(
                                          'file_avatar_${avatarFile.path}_$_avatarVersion'),
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    )
                          : const _AvatarPlaceholder(),
                    ),
                  ),
                  if (_updatingAvatar)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.44),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textPrimary.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 15,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
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
                color: AppTheme.textPrimary.withValues(alpha: 0.78),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary.withValues(alpha: 0.93),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isAdmin = auth.isAdmin;

    return Drawer(
      backgroundColor: _drawerBg,
      child: Column(
        children: [
          _buildHeader(auth, isAdmin),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                _DrawerItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  color: AppTheme.accentColor,
                  isActive: widget.selectedItem == AppDrawer.dashboard,
                  onTap: () => _goDashboard(context),
                ),
                const _DrawerSection(title: 'Atendimento'),
                _DrawerItem(
                  icon: Icons.receipt_long,
                  label: 'Comandas',
                  color: AppTheme.accentColor,
                  isActive: widget.selectedItem == AppDrawer.comandas,
                  onTap: () => _navigateTo(
                      context, AppRoutes.comandas, AppDrawer.comandas),
                ),
                _DrawerItem(
                  icon: Icons.content_cut,
                  label: 'Atendimentos',
                  color: AppTheme.accentColor,
                  isActive: widget.selectedItem == AppDrawer.atendimentos,
                  onTap: () => _navigateTo(
                      context, AppRoutes.atendimentos, AppDrawer.atendimentos),
                ),
                _DrawerItem(
                  icon: Icons.event,
                  label: 'Agenda',
                  color: AppTheme.infoColor,
                  isActive: widget.selectedItem == AppDrawer.agenda,
                  onTap: () =>
                      _navigateTo(context, AppRoutes.agenda, AppDrawer.agenda),
                ),
                const _DrawerSection(title: 'Cadastros'),
                _DrawerItem(
                  icon: Icons.people,
                  label: 'Clientes',
                  color: AppTheme.infoColor,
                  isActive: widget.selectedItem == AppDrawer.clientes,
                  onTap: () => _navigateTo(
                      context, AppRoutes.clientes, AppDrawer.clientes),
                ),
                if (isAdmin) ...[
                  _DrawerItem(
                    icon: Icons.badge_outlined,
                    label: 'Adicionar Barbeiro',
                    color: AppTheme.goldColor,
                    isActive: widget.selectedItem == AppDrawer.barbeiros,
                    onTap: () => _navigateTo(
                      context,
                      AppRoutes.barbeiros,
                      AppDrawer.barbeiros,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.design_services,
                    label: 'Serviços',
                    color: AppTheme.warningColor,
                    isActive: widget.selectedItem == AppDrawer.servicos,
                    onTap: () => _navigateTo(
                        context, AppRoutes.servicos, AppDrawer.servicos),
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_bag,
                    label: 'Produtos',
                    color: AppTheme.successColor,
                    isActive: widget.selectedItem == AppDrawer.produtos,
                    onTap: () => _navigateTo(
                        context, AppRoutes.produtos, AppDrawer.produtos),
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_2,
                    label: 'Estoque',
                    color: AppTheme.warningColor,
                    isActive: widget.selectedItem == AppDrawer.estoque,
                    onTap: () => _navigateTo(
                        context, AppRoutes.estoque, AppDrawer.estoque),
                  ),
                  const _DrawerSection(title: 'Financeiro'),
                  _DrawerItem(
                    icon: Icons.attach_money,
                    label: 'Financeiro',
                    color: AppTheme.goldColor,
                    isActive: widget.selectedItem == AppDrawer.financeiro,
                    onTap: () => _navigateTo(
                        context, AppRoutes.financeiro, AppDrawer.financeiro),
                  ),
                  _DrawerItem(
                    icon: Icons.point_of_sale,
                    label: 'Caixa',
                    color: AppTheme.successColor,
                    isActive: widget.selectedItem == AppDrawer.caixa,
                    onTap: () =>
                        _navigateTo(context, AppRoutes.caixa, AppDrawer.caixa),
                  ),
                  const _DrawerSection(title: 'Analises'),
                  _DrawerItem(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    color: AppTheme.infoColor,
                    isActive: widget.selectedItem == AppDrawer.analytics,
                    onTap: () => _navigateTo(
                        context, AppRoutes.analytics, AppDrawer.analytics),
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events,
                    label: 'Ranking de Clientes',
                    color: AppTheme.goldColor,
                    isActive: widget.selectedItem == AppDrawer.ranking,
                    onTap: () => _navigateTo(
                        context, AppRoutes.ranking, AppDrawer.ranking),
                  ),
                  _DrawerItem(
                    icon: Icons.summarize,
                    label: 'Relatórios',
                    color: AppTheme.errorColor,
                    isActive: widget.selectedItem == AppDrawer.relatorios,
                    onTap: () => _navigateTo(
                        context, AppRoutes.relatorios, AppDrawer.relatorios),
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
                  color: _drawerTextSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (ctx, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Icon(
                            dark ? Icons.dark_mode : Icons.light_mode,
                            color: _drawerTextSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Modo Escuro',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: _drawerTextPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            height: 40,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Switch.adaptive(
                                value: dark,
                                activeThumbColor: AppTheme.accentColor,
                                onChanged: (v) {
                                  themeModeNotifier.value =
                                      v ? ThemeMode.dark : ThemeMode.light;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: GoogleFonts.inter(
                      color: _drawerTextSecondary,
                      fontSize: 12,
                    ),
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
    final route =
        auth.isAdmin ? AppRoutes.dashboardAdmin : AppRoutes.dashboardBarbeiro;
    _navigateTo(context, route, AppDrawer.dashboard);
  }

  void _navigateTo(BuildContext context, String route, String key) {
    Navigator.pop(context);
    if (widget.selectedItem == key) return;
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

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'S',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;

  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0)
        : Colors.transparent;
    final activeBg = isDark
        ? AppTheme.secondaryColor.withValues(alpha: 0.95)
        : AppTheme.lightInputFill;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? activeBg : baseBg,
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
            color: textColor,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
