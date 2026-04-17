import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/comanda_controller.dart';
import '../../models/comanda.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';
import 'abrir_comanda_screen.dart';

class ComandasScreen extends StatefulWidget {
  const ComandasScreen({super.key});

  @override
  State<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends State<ComandasScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabController;
  late Future<List<Comanda>> _futureFechadas;
  late Future<List<Comanda>> _futureAbertas;
  int _abertasCount = 0;
  int _fechadasCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _carregar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final auth = context.read<AuthController>();
    final comandaController = context.read<ComandaController>();
    final barbeiroId = auth.isAdmin ? null : auth.usuarioId;
    final futurasAbertas = comandaController.getAll(
      barbeiroId: barbeiroId,
      status: 'aberta',
    );
    final futurasFechadas = comandaController.getAll(
      barbeiroId: barbeiroId,
      status: 'fechada',
    );

    setState(() {
      _futureAbertas = futurasAbertas;
      _futureFechadas = futurasFechadas;
    });

    try {
      final resultados = await Future.wait<List<Comanda>>([
        futurasAbertas,
        futurasFechadas,
      ]);
      if (!mounted) return;
      setState(() {
        _abertasCount = resultados[0].length;
        _fechadasCount = resultados[1].length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _abertasCount = 0;
        _fechadasCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasComandasNoTabAtivo =
        _tabController.index == 0 ? _abertasCount > 0 : _fechadasCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comandas',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black87,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Abertas'),
            Tab(text: 'Fechadas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.comandas),
      floatingActionButton: hasComandasNoTabAtivo
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AbrirComandaScreen()),
                );
                _carregar();
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Nova comanda',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppTheme.accentColor,
            )
          : null,
      body: AppPageContainer(
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por cliente ou barbeiro',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLista(
                    _futureAbertas,
                    title: 'Comandas abertas',
                    emptyTitle: 'Nenhuma comanda aberta',
                    emptySubtitle:
                        'Crie uma nova comanda para iniciar o atendimento.',
                  ),
                  _buildLista(
                    _futureFechadas,
                    title: 'Comandas fechadas',
                    emptyTitle: 'Nenhuma comanda fechada',
                    emptySubtitle:
                        'As comandas finalizadas do período aparecerão aqui.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(
    Future<List<Comanda>> future, {
    required String title,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return FutureBuilder<List<Comanda>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AppErrorState(
            title: 'Falha ao carregar comandas',
            subtitle: 'Verifique sua conexão e tente novamente.',
            onRetry: _carregar,
          );
        }

        final query = _searchCtrl.text.trim().toLowerCase();
        final fullList = snapshot.data ?? const <Comanda>[];
        final filtered = query.isEmpty
            ? fullList
            : fullList.where((comanda) {
                final cliente = comanda.clienteNome.toLowerCase();
                final barbeiro = (comanda.barbeiroNome ?? '').toLowerCase();
                return cliente.contains(query) || barbeiro.contains(query);
              }).toList(growable: false);

        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: Icons.receipt_long,
            title:
                query.isEmpty ? emptyTitle : 'Nenhum resultado para "$query"',
            subtitle: query.isEmpty
                ? emptySubtitle
                : 'Ajuste a busca ou limpe o filtro para ver todas as comandas.',
            actionLabel: query.isEmpty ? 'Nova comanda' : null,
            onAction: query.isEmpty
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AbrirComandaScreen(),
                      ),
                    );
                    _carregar();
                  }
                : null,
          );
        }

        final total = filtered.fold<double>(0, (s, c) => s + c.total);
        return RefreshIndicator(
          onRefresh: () async => _carregar(),
          child: ListView.builder(
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildResumoHeader(
                    title: title,
                    quantidade: filtered.length,
                    total: total,
                  ),
                );
              }
              final comanda = filtered[index - 1];
              return _buildCard(comanda);
            },
          ),
        );
      },
    );
  }

  Widget _buildResumoHeader({
    required String title,
    required int quantidade,
    required double total,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$quantidade item(ns)',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppFormatters.currency(total),
            style: GoogleFonts.poppins(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Comanda comanda) {
    final isAberta = comanda.status == 'aberta';
    final color = isAberta ? AppTheme.warningColor : AppTheme.successColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            isAberta ? Icons.receipt_long : Icons.check_circle,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          comanda.clienteNome,
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${comanda.barbeiroNome ?? "Sem barbeiro"} • '
          '${AppFormatters.dateTime(comanda.dataAbertura)}',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.currency(comanda.total),
              style: GoogleFonts.poppins(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Comissão: ${AppFormatters.currency(comanda.comissaoTotal)}',
              style: GoogleFonts.inter(color: AppTheme.goldColor, fontSize: 11),
            ),
          ],
        ),
        onTap: isAberta
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AbrirComandaScreen(comandaExistente: comanda),
                  ),
                );
                _carregar();
              }
            : null,
      ),
    );
  }
}
