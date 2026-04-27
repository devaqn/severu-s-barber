// ============================================================
// constants.dart
// Constantes globais usadas em todo o aplicativo.
// Centraliza valores fixos para facilitar manutenção.
// ============================================================

class AppConstants {
  // ── Nome do aplicativo ──────────────────────────────────────────────
  static const String appName = 'Severus Barber';
  static const String appVersion = '5.0.0';

  // ── Nome do banco de dados ──────────────────────────────────────────
  static const String dbName = 'barbearia_pro.db';
  static const int dbVersion = 7;

  // ── Nomes das tabelas do banco ──────────────────────────────────────
  static const String tableClientes = 'clientes';
  static const String tableServicos = 'servicos';
  static const String tableProdutos = 'produtos';
  static const String tableFornecedores = 'fornecedores';
  static const String tableAtendimentos = 'atendimentos';
  static const String tableAtendimentoItens = 'atendimento_itens';
  static const String tableAgendamentos = 'agendamentos';
  static const String tableDespesas = 'despesas';
  static const String tableMovimentosEstoque = 'movimentos_estoque';
  static const String tableCaixas = 'caixas';
  static const String tableUsuarios = 'usuarios';
  static const String tableComandas = 'comandas';
  static const String tableComandasItens = 'comandas_itens';
  static const String tableComissoes = 'comissoes';
  static const String collectionBarbearias = 'barbearias';
  static const String localBarbeariaId = 'barbearia_local';

  // ── Tipos de usuário ────────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleBarbeiro = 'barbeiro';

  // ── Status de comanda ───────────────────────────────────────────────
  static const String comandaAberta = 'aberta';
  static const String comandaFechada = 'fechada';
  static const String comandaCancelada = 'cancelada';

  // ── Formas de pagamento ─────────────────────────────────────────────
  static const String pgDinheiro = 'Dinheiro';
  static const String pgPix = 'PIX';
  static const String pgCredito = 'Cartão de Crédito';
  static const String pgDebito = 'Cartão de Débito';

  static const List<String> formasPagamento = [
    pgDinheiro,
    pgPix,
    pgCredito,
    pgDebito,
  ];

  // ── Categorias de despesa ───────────────────────────────────────────
  static const List<String> categoriasDespesa = [
    'Aluguel',
    'Energia Elétrica',
    'Luz',
    'Internet',
    'Água',
    'Compra de Produtos',
    'Manutenção',
    'Marketing',
    'Salários',
    'Equipamentos',
    'Comissões',
    'Outros',
  ];

  // ── Status de agendamento ───────────────────────────────────────────
  static const String statusPendente = 'Pendente';
  static const String statusConfirmado = 'Confirmado';
  static const String statusConcluido = 'Concluído';
  static const String statusCancelado = 'Cancelado';

  static const List<String> statusAgendamento = [
    statusPendente,
    statusConfirmado,
    statusConcluido,
    statusCancelado,
  ];

  // ── Status de caixa ─────────────────────────────────────────────────
  static const String caixaAberto = 'aberto';
  static const String caixaFechado = 'fechado';

  // ── Tipos de movimento de estoque ───────────────────────────────────
  static const String estoqueEntrada = 'entrada';
  static const String estoqueSaida = 'saida';

  // ── Programa de fidelidade ──────────────────────────────────────────
  /// Quantidade de atendimentos para ganhar um bônus
  static const int cortesFidelidade = 10;

  // ── Limites de estoque baixo (padrão) ──────────────────────────────
  static const int estoqueMinimoPadrao = 3;

  // ── Configurações de gráfico ────────────────────────────────────────
  static const int diasGraficoFaturamento = 30;
  static const int kSyncBatchSize = 20;

  // ── Análise de clientes sumidos ─────────────────────────────────────
  /// Se o cliente não aparece em X dias após sua média, é marcado como "sumido"
  static const int diasToleranciaCliente = 15;

  // ── Comissões padrão ────────────────────────────────────────────────
  /// Percentual padrão de comissão do barbeiro em serviços (50%)
  static const double comissaoServicoPadrao = 0.50;

  /// Percentual padrão de comissão do barbeiro em produtos (20%)
  static const double comissaoProdutoPadrao = 0.20;
}
