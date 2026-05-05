// ============================================================
// dashboard_service.dart
// Serviço agregador do dashboard com base em comandas + financeiro.
// ============================================================

import 'agenda_service.dart';
import 'cliente_service.dart';
import 'comanda_service.dart';
import 'financeiro_service.dart';
import 'produto_service.dart';

class DashboardService {
  DashboardService({
    ComandaService? comandaService,
    FinanceiroService? financeiroService,
    ProdutoService? produtoService,
    ClienteService? clienteService,
    AgendaService? agendaService,
  })  : _comandaService = comandaService ?? ComandaService(),
        _financeiroService = financeiroService ?? FinanceiroService(),
        _produtoService = produtoService ?? ProdutoService(),
        _clienteService = clienteService ?? ClienteService(),
        _agendaService = agendaService ?? AgendaService();

  final ComandaService _comandaService;
  final FinanceiroService _financeiroService;
  final ProdutoService _produtoService;
  final ClienteService _clienteService;
  final AgendaService _agendaService;

  Future<Map<String, dynamic>> getDadosDashboard() async {
    final agora = DateTime.now().toUtc();
    final inicioDia = DateTime.utc(agora.year, agora.month, agora.day);
    final fimDia = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59);
    final inicioSemana = agora.subtract(Duration(days: agora.weekday - 1));
    final inicioMes = DateTime.utc(agora.year, agora.month, 1);

    final results = await Future.wait([
      _comandaService.getFaturamentoPeriodo(inicioDia, fimDia),
      _comandaService.getFaturamentoPeriodo(inicioSemana, agora),
      _comandaService.getFaturamentoPeriodo(inicioMes, agora),
      _comandaService.getCountComandasFechadasPeriodo(inicioDia, fimDia),
      _comandaService.getCountComandasFechadasPeriodo(inicioMes, agora),
      _produtoService.getValorTotalEstoque(),
      _produtoService.getProdutosEstoqueBaixo(),
      _comandaService.getFaturamentoPorDia(30),
      _agendaService.getProximos(limit: 5),
      _clienteService.getRanking(limit: 5),
    ]);

    final faturamentoDia = results[0] as double;
    final faturamentoSemana = results[1] as double;
    final faturamentoMes = results[2] as double;
    final atendimentosDia = results[3] as int;
    final atendimentosMes = results[4] as int;
    final valorEstoque = results[5] as double;

    final despesasMes =
        await _financeiroService.getTotalDespesas(inicioMes, agora);
    final lucroEstimado = faturamentoMes - despesasMes;

    return {
      'faturamentoDia': faturamentoDia,
      'faturamentoSemana': faturamentoSemana,
      'faturamentoMes': faturamentoMes,
      'atendimentosDia': atendimentosDia,
      'atendimentosMes': atendimentosMes,
      'valorEstoque': valorEstoque,
      'lucroEstimado': lucroEstimado,
      'despesasMes': despesasMes,
      'produtosEstoqueBaixo': results[6],
      'faturamentoPorDia': results[7],
      'proximosAgendamentos': results[8],
      'topClientes': results[9],
    };
  }
}
