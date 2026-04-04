// ============================================================
// dashboard_service.dart
// Serviço que agrega dados para o Dashboard principal.
// Consolida faturamento, atendimentos, alertas e gráficos.
// ============================================================

import 'atendimento_service.dart';
import 'financeiro_service.dart';
import 'produto_service.dart';
import 'cliente_service.dart';
import 'agenda_service.dart';

class DashboardService {
  final AtendimentoService _atendimentoService = AtendimentoService();
  final FinanceiroService _financeiroService = FinanceiroService();
  final ProdutoService _produtoService = ProdutoService();
  final ClienteService _clienteService = ClienteService();
  final AgendaService _agendaService = AgendaService();

  /// Carrega todos os dados necessários para o dashboard
  Future<Map<String, dynamic>> getDadosDashboard() async {
    final agora = DateTime.now();
    final inicioDia = DateTime(agora.year, agora.month, agora.day);
    final fimDia = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    final inicioSemana = agora.subtract(Duration(days: agora.weekday - 1));
    final inicioMes = DateTime(agora.year, agora.month, 1);

    // Carrega dados em paralelo para melhor performance
    final results = await Future.wait([
      _atendimentoService.getFaturamentoPeriodo(inicioDia, fimDia),
      _atendimentoService.getFaturamentoPeriodo(inicioSemana, agora),
      _atendimentoService.getFaturamentoPeriodo(inicioMes, agora),
      _atendimentoService.getCountPeriodo(inicioDia, fimDia),
      _atendimentoService.getCountPeriodo(inicioMes, agora),
      _produtoService.getValorTotalEstoque(),
      _produtoService.getProdutosEstoqueBaixo(),
      _atendimentoService.getFaturamentoPorDia(30),
      _agendaService.getProximos(limit: 5),
      _clienteService.getRanking(limit: 5),
    ]);

    final faturamentoDia = results[0] as double;
    final faturamentoSemana = results[1] as double;
    final faturamentoMes = results[2] as double;
    final atendimentosDia = results[3] as int;
    final atendimentosMes = results[4] as int;
    final valorEstoque = results[5] as double;

    // Cálculo de despesas do mês para lucro estimado
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
