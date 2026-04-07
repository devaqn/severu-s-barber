import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/cliente_controller.dart';
import '../../models/cliente.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';
import 'cliente_detalhe_screen.dart';
import 'cliente_form_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final ClienteController _controller = ClienteController();
  final TextEditingController _buscaCtrl = TextEditingController();

  bool _mostrarBusca = false;

  @override
  void initState() {
    super.initState();
    _controller.carregar();
    _buscaCtrl.addListener(() {
      _controller.buscar(_buscaCtrl.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _novoCliente() async {
    final cliente = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(builder: (_) => const ClienteFormScreen()),
    );
    if (cliente == null) return;
    try {
      await _controller.salvar(cliente);
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Cliente cadastrado com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao salvar cliente: $e',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<void> _editarCliente(Cliente cliente) async {
    final atualizado = await Navigator.push<Cliente>(
      context,
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente)),
    );
    if (atualizado == null) return;
    try {
      await _controller.salvar(atualizado);
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Cliente atualizado com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao atualizar cliente: $e',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<void> _deletarCliente(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: Text('Deseja excluir ${cliente.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || cliente.id == null) return;

    try {
      await _controller.deletar(cliente.id!);
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Cliente removido com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao excluir cliente: $e',
          type: AppNoticeType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const lightBg = Color(0xFFF7F7FA);
    const cardRadius = 16.0;

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        surfaceTintColor: lightBg,
        elevation: 0,
        title: _mostrarBusca
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightDivider),
                ),
                child: TextField(
                  controller: _buscaCtrl,
                  autofocus: true,
                  style: GoogleFonts.inter(color: AppTheme.lightTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente por nome',
                    hintStyle:
                        GoogleFonts.inter(color: AppTheme.lightTextSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              )
            : Text(
                'Clientes',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
        actions: [
          IconButton(
            color: AppTheme.lightTextPrimary,
            icon: Icon(_mostrarBusca ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _mostrarBusca = !_mostrarBusca;
                if (!_mostrarBusca) {
                  _buscaCtrl.clear();
                }
              });
            },
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.clientes),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: _novoCliente,
        icon: const Icon(Icons.add),
        label: Text(
          '+ Novo Cliente',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        color: lightBg,
        child: AppPageContainer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isLoading &&
                  _controller.clientesFiltrados.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_controller.clientesFiltrados.isEmpty) {
                final semBusca = _buscaCtrl.text.trim().isEmpty;
                return _buildEmptyStateLight(
                  title: 'Nenhum cliente encontrado',
                  subtitle: semBusca
                      ? 'Cadastre o primeiro cliente para iniciar o relacionamento.'
                      : 'Ajuste a busca para encontrar clientes.',
                  actionLabel: semBusca ? '+ Novo Cliente' : null,
                  onAction: semBusca ? _novoCliente : null,
                );
              }

              return RefreshIndicator(
                onRefresh: _controller.carregar,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
                  itemCount: _controller.clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = _controller.clientesFiltrados[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Slidable(
                        key: ValueKey(cliente.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          children: [
                            SlidableAction(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(cardRadius),
                                bottomLeft: Radius.circular(cardRadius),
                              ),
                              onPressed: (_) => _editarCliente(cliente),
                              backgroundColor: AppTheme.infoColor,
                              foregroundColor: Colors.white,
                              icon: Icons.edit,
                              label: 'Editar',
                            ),
                            SlidableAction(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(cardRadius),
                                bottomRight: Radius.circular(cardRadius),
                              ),
                              onPressed: (_) => _deletarCliente(cliente),
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Excluir',
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(cardRadius),
                            border: Border.all(color: AppTheme.lightDivider),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClienteDetalheScreen(cliente: cliente),
                                ),
                              );
                              await _controller.carregar();
                            },
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.accentColor,
                                    AppTheme.accentDark
                                  ],
                                ),
                              ),
                              child: Icon(
                                cliente.temCorteGratis
                                    ? Icons.emoji_events
                                    : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cliente.nome,
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.lightTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (cliente.pontosFidelidade >= 10)
                                  const Icon(Icons.emoji_events,
                                      color: AppTheme.goldColor),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppFormatters.phone(cliente.telefone),
                                    style: GoogleFonts.inter(
                                        color: AppTheme.lightTextSecondary),
                                  ),
                                  Text(
                                    'Última visita: ${cliente.ultimaVisita != null ? AppFormatters.relativeDate(cliente.ultimaVisita!) : 'Sem registro'}',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.lightTextSecondary),
                                  ),
                                  Text(
                                    'Fidelidade: ${cliente.pontosFidelidade} pontos',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.lightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              AppFormatters.currency(cliente.totalGasto),
                              style: GoogleFonts.poppins(
                                color: AppTheme.successDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateLight({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightDivider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline,
                color: AppTheme.lightTextSecondary, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.lightTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.lightTextSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
