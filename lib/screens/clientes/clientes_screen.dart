// ============================================================
// clientes_screen.dart
// Lista de clientes com busca, slidable e navegacao de detalhe.
// ============================================================

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

/// Tela principal de clientes com busca, cadastro e gerenciamento rapido.
class ClientesScreen extends StatefulWidget {
  /// Construtor padrao da tela de clientes.
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

/// Estado da listagem de clientes com filtros e operacoes CRUD.
class _ClientesScreenState extends State<ClientesScreen> {
  // Controller de estado da tela de clientes.
  final ClienteController _controller = ClienteController();

  // Controlador do texto de busca no appbar.
  final TextEditingController _buscaCtrl = TextEditingController();

  // Flag de exibicao do campo de busca no appbar.
  bool _mostrarBusca = false;

  @override
  void initState() {
    super.initState();
    // Carrega lista inicial de clientes.
    _controller.carregar();
    _buscaCtrl.addListener(() {
      _controller.buscar(_buscaCtrl.text);
    });
  }

  @override
  void dispose() {
    // Libera controller de tela e campo de busca.
    _controller.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  /// Abre formulario para inserir novo cliente e salva resultado.
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

  /// Abre formulario em modo edicao para cliente selecionado.
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

  /// Remove cliente selecionado apos confirmacao.
  Future<void> _deletarCliente(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: Text('Deseja excluir ${cliente.nome}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
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
    // Layout principal com drawer e lista de clientes.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: _mostrarBusca
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentColor),
                ),
                child: TextField(
                  controller: _buscaCtrl,
                  autofocus: true,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente por nome',
                    hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              )
            : Text(
                'Clientes',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 18),
              ),
        actions: [
          IconButton(
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
        backgroundColor: AppTheme.accentColor,
        onPressed: _novoCliente,
        icon: const Icon(Icons.add, color: AppTheme.textPrimary),
        label: const Text('Novo cliente'),
      ),
      body: AppPageContainer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isLoading &&
                _controller.clientesFiltrados.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_controller.clientesFiltrados.isEmpty) {
              return AppEmptyState(
                icon: Icons.people_outline,
                title: 'Nenhum cliente encontrado',
                subtitle: _buscaCtrl.text.trim().isEmpty
                    ? 'Cadastre o primeiro cliente para iniciar o relacionamento.'
                    : 'Ajuste a busca para encontrar clientes.',
                actionLabel:
                    _buscaCtrl.text.trim().isEmpty ? 'Novo cliente' : null,
                onAction: _buscaCtrl.text.trim().isEmpty ? _novoCliente : null,
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
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            onPressed: (_) => _editarCliente(cliente),
                            backgroundColor: AppTheme.infoColor,
                            foregroundColor: AppTheme.textPrimary,
                            icon: Icons.edit,
                            label: 'Editar',
                          ),
                          SlidableAction(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            onPressed: (_) => _deletarCliente(cliente),
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: AppTheme.textPrimary,
                            icon: Icons.delete,
                            label: 'Excluir',
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cliente.nome,
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.textPrimary,
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
                                      color: AppTheme.textSecondary),
                                ),
                                Text(
                                  'Última visita: ${cliente.ultimaVisita != null ? AppFormatters.relativeDate(cliente.ultimaVisita!) : 'Sem registro'}',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary),
                                ),
                                Text(
                                  'Fidelidade: ${cliente.pontosFidelidade} pontos',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          trailing: Text(
                            AppFormatters.currency(cliente.totalGasto),
                            style: GoogleFonts.poppins(
                              color: AppTheme.successColor,
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
    );
  }
}
