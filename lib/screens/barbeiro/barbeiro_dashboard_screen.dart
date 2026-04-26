// ============================================================
// barbeiro_dashboard_screen.dart
// Dashboard do barbeiro: ganhos, atendimentos e comissões.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cliente_controller.dart';
import '../../controllers/comanda_controller.dart';
import '../../models/cliente.dart';
import '../../models/comanda.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';
import '../comanda/comandas_screen.dart';
import '../comanda/abrir_comanda_screen.dart';

/// Dashboard individual do barbeiro com seus ganhos e atendimentos do dia.
class BarbeiroDashboardScreen extends StatefulWidget {
  const BarbeiroDashboardScreen({super.key});

  @override
  State<BarbeiroDashboardScreen> createState() =>
      _BarbeiroDashboardScreenState();
}

class _BarbeiroDashboardScreenState extends State<BarbeiroDashboardScreen> {
  ComandaController get _comandaController => context.read<ComandaController>();
  ClienteController get _clienteController => context.read<ClienteController>();
  late Future<Map<String, dynamic>> _futureDados;

  @override
  void initState() {
    super.initState();
    _futureDados = _carregarDados();
  }

  Future<void> _recarregar() async {
    setState(() => _futureDados = _carregarDados());
  }

  /// Carrega os dados do barbeiro logado
  Future<Map<String, dynamic>> _carregarDados() async {
    final ctrl = context.read<AuthController>();
    final barbeiroId = ctrl.usuarioId;
    final agora = DateTime.now();
    final inicioDia = DateTime(agora.year, agora.month, agora.day);
    final fimDia = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    final inicioMes = DateTime(agora.year, agora.month, 1);

    final results = await Future.wait([
      _comandaController.getFaturamentoBarbeiro(barbeiroId, inicioDia, fimDia),
      _comandaController.getFaturamentoBarbeiro(barbeiroId, inicioMes, agora),
      _comandaController.getComissaoBarbeiro(barbeiroId, inicioDia, fimDia),
      _comandaController.getComissaoBarbeiro(barbeiroId, inicioMes, agora),
      _comandaController.getComandasHoje(barbeiroId: barbeiroId),
      _comandaController.getComandaAberta(barbeiroId: barbeiroId),
      _clienteController.aniversariantesHoje(),
    ]);

    return {
      'fatHoje': results[0] as double,
      'fatMes': results[1] as double,
      'comissaoHoje': results[2] as double,
      'comissaoMes': results[3] as double,
      'comandasHoje': results[4] as List<Comanda>,
      'comandaAberta': results[5] as Comanda?,
      'aniversariantesHoje': results[6] as List<Cliente>,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.purpleStart, AppTheme.purpleEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${ctrl.usuarioNome.split(' ').first}!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Barbeiro',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _recarregar,
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.dashboard),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AbrirComandaScreen()),
          );
          _recarregar();
        },
        backgroundColor: AppTheme.accentColor,
        icon: const Icon(Icons.add, color: AppTheme.textPrimary),
        label: Text(
          'Nova Comanda',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureDados,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppPageContainer(
              child: AppErrorState(
                title: 'Falha ao carregar seus dados',
                subtitle: 'Tente novamente para atualizar o painel.',
                onRetry: _recarregar,
              ),
            );
          }

          final data = snapshot.data!;
          final fatHoje = (data['fatHoje'] as double?) ?? 0.0;
          final fatMes = (data['fatMes'] as double?) ?? 0.0;
          final comissaoHoje = (data['comissaoHoje'] as double?) ?? 0.0;
          final comissaoMes = (data['comissaoMes'] as double?) ?? 0.0;
          final comandasHoje =
              (data['comandasHoje'] as List<Comanda>?) ?? const <Comanda>[];
          final comandaAberta = data['comandaAberta'] as Comanda?;
          final aniversariantesHoje =
              ((data['aniversariantesHoje'] as List?) ?? const [])
                  .cast<Cliente>();

          return AppPageContainer(
            child: RefreshIndicator(
              onRefresh: _recarregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (aniversariantesHoje.isNotEmpty)
                      _buildBannerAniversariantes(aniversariantesHoje),
                    if (aniversariantesHoje.isNotEmpty)
                      const SizedBox(height: 12),
                    // Alerta de comanda aberta
                    if (comandaAberta != null)
                      _buildAlertaComanda(comandaAberta),
                    const SizedBox(height: 12),

                    // Cards de ganhos
                    _buildSectionTitle('Seus Ganhos'),
                    const SizedBox(height: 10),
                    _buildCardGrid([
                      _GanhoCard(
                        titulo: 'Faturado Hoje',
                        valor: fatHoje,
                        icon: Icons.today,
                        color: AppTheme.infoColor,
                      ),
                      _GanhoCard(
                        titulo: 'Faturado no Mês',
                        valor: fatMes,
                        icon: Icons.calendar_month,
                        color: AppTheme.successColor,
                      ),
                      _GanhoCard(
                        titulo: 'Comissão Hoje',
                        valor: comissaoHoje,
                        icon: Icons.payments_outlined,
                        color: AppTheme.goldColor,
                      ),
                      _GanhoCard(
                        titulo: 'Comissão do Mês',
                        valor: comissaoMes,
                        icon: Icons.monetization_on_outlined,
                        color: AppTheme.purpleStart,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Comandas do dia
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Atendimentos Hoje'),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ComandasScreen()),
                          ),
                          child: const Text('Ver todos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (comandasHoje.isEmpty)
                      _buildEmptyState(
                          'Nenhuma comanda hoje ainda', Icons.receipt_long)
                    else
                      ...comandasHoje.map((c) => _buildComandaCard(c)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertaComanda(Comanda comanda) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comanda Aberta',
                  style: GoogleFonts.poppins(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  comanda.clienteNome,
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AbrirComandaScreen(comandaExistente: comanda),
                ),
              );
              _recarregar();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildBannerAniversariantes(List<Cliente> clientes) {
    final nomes = clientes.map((c) => c.nome).join(', ');
    final contatos = clientes
        .map((c) =>
            '${c.nome.split(' ').first}: ${AppFormatters.phone(c.telefone)}')
        .join('  •  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cake, color: Color(0xFFD4AF37)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aniversariantes de Hoje',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  nomes,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contatos,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(List<_GanhoCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 620 ? 1 : 2;
        final aspect = crossAxisCount == 1 ? 3.1 : 1.4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspect,
          children: cards,
        );
      },
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 40),
          const SizedBox(height: 10),
          Text(msg, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildComandaCard(Comanda c) {
    final isFechada = c.status == 'fechada';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                (isFechada ? AppTheme.successColor : AppTheme.warningColor)
                    .withValues(alpha: 0.2),
            child: Icon(
              isFechada ? Icons.check : Icons.receipt_long,
              color: isFechada ? AppTheme.successColor : AppTheme.warningColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.clienteNome,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  AppFormatters.time(c.dataAbertura),
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.currency(c.total),
                style: GoogleFonts.poppins(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Comissão: ${AppFormatters.currency(c.comissaoTotal)}',
                style:
                    GoogleFonts.inter(color: AppTheme.goldColor, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de ganho individual para o grid do barbeiro
class _GanhoCard extends StatelessWidget {
  final String titulo;
  final double valor;
  final IconData icon;
  final Color color;

  const _GanhoCard({
    required this.titulo,
    required this.valor,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppFormatters.currency(valor),
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                titulo,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
