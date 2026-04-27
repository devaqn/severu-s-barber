// ============================================================
// backend_simulation_test.dart
// Testes de integração para services SQLite (sem Firebase).
// Cobre: clientes, agendamentos, atendimentos, comandas,
//        produtos, despesas, caixa e regras de negócio.
// ============================================================

import 'package:barbearia_pro/database/database_helper.dart';
import 'package:barbearia_pro/models/agendamento.dart';
import 'package:barbearia_pro/models/atendimento.dart';
import 'package:barbearia_pro/models/caixa.dart';
import 'package:barbearia_pro/models/cliente.dart';
import 'package:barbearia_pro/models/despesa.dart';
import 'package:barbearia_pro/models/item_comanda.dart';
import 'package:barbearia_pro/models/produto.dart';
import 'package:barbearia_pro/models/servico.dart';
import 'package:barbearia_pro/models/usuario.dart';
import 'package:barbearia_pro/services/agenda_service.dart';
import 'package:barbearia_pro/services/atendimento_service.dart';
import 'package:barbearia_pro/services/auth_service.dart';
import 'package:barbearia_pro/services/cliente_service.dart';
import 'package:barbearia_pro/services/comanda_service.dart';
import 'package:barbearia_pro/services/financeiro_service.dart';
import 'package:barbearia_pro/services/produto_service.dart';
import 'package:barbearia_pro/services/service_exceptions.dart';
import 'package:barbearia_pro/services/servico_service.dart';
import 'package:barbearia_pro/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final db = DatabaseHelper();
  final clienteService = ClienteService();
  final agendaService = AgendaService();
  final atendimentoService = AtendimentoService();
  final comandaService = ComandaService();
  final produtoService = ProdutoService();
  final financeiroService = FinanceiroService();
  final servicoService = ServicoService();
  final authService = AuthService();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.setDatabaseNameForTests(
        'barbearia_pro_backend_test.db');
    await db.deleteDatabaseFile();
    await db.database;
  });

  tearDownAll(() async {
    await db.deleteDatabaseFile();
    await DatabaseHelper.setDatabaseNameForTests(null);
  });

  setUp(() async {
    await db.resetForTests(seedDefaultData: true);
  });

  // Note: phone sanitization removes formatting chars — pass digits only.
  // ItemComanda.comissaoPercentual uses 0.0–1.0 scale (0.5 = 50%).
  // AtendimentoItem.total must match sum of item subtotals exactly.

  // ─── GRUPO 1: CLIENTES ──────────────────────────────────────────────────────

  group('Clientes', () {
    test('Cadastro e recuperação com UTF-8', () async {
      final id = await clienteService.insert(Cliente(
        nome: 'João da Silva Filho',
        telefone: '11988887777',
        observacoes: 'Prefere atendimento no fim da tarde e sábado',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(id, greaterThan(0));

      final c = await clienteService.getById(id);
      expect(c, isNotNull);
      expect(c!.nome, 'João da Silva Filho');
    });

    test('Atualização de dados do cliente', () async {
      final id = await clienteService.insert(Cliente(
        nome: 'Maria Oliveira',
        telefone: '11977771234',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final original = await clienteService.getById(id);
      await clienteService.update(original!.copyWith(
        telefone: '11966669999',
        observacoes: 'Atualizada',
      ));

      final atualizado = await clienteService.getById(id);
      expect(atualizado!.telefone, '11966669999');
    });

    test('Listagem de clientes retorna ao menos 1 após inserção', () async {
      await clienteService.insert(Cliente(
        nome: 'Pedro Costa',
        telefone: '21987654321',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final lista = await clienteService.getAll();
      expect(lista.isNotEmpty, isTrue);
    });

    test(
        'Histórico de atendimentos e total gasto atualizam ao registrar atendimento',
        () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Histórico',
        telefone: '11955551111',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await atendimentoService.registrar(Atendimento(
        clienteId: clienteId,
        clienteNome: 'Cliente Histórico',
        total: 80.0,
        formaPagamento: 'PIX',
        data: DateTime.now(),
        itens: const [
          AtendimentoItem(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte de Cabelo',
            quantidade: 1,
            precoUnitario: 80.0,
          ),
        ],
      ));

      final c = await clienteService.getById(clienteId);
      expect(c!.totalAtendimentos, 1);
      expect(c.totalGasto, closeTo(80.0, 0.001));
    });

    test('Clientes sumidos usa agenda concluida sem N+1', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Sumido',
        telefone: '11912345678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final agora = DateTime.now();
      for (final dias in const [120, 90, 60]) {
        final data = agora.subtract(Duration(days: dias));
        await db.insert(AppConstants.tableAgendamentos, {
          'cliente_id': clienteId,
          'cliente_nome': 'Cliente Sumido',
          'servico_id': 1,
          'servico_nome': 'Corte de Cabelo',
          'data_hora': data.toIso8601String(),
          'status': AppConstants.statusConcluido,
          'faturamento_registrado': 1,
          'created_at': data.toIso8601String(),
          'updated_at': data.toIso8601String(),
        });
      }

      final sumidos = await clienteService.getClientesSumidos();
      expect(
        sumidos.any((item) => (item['cliente'] as Cliente).id == clienteId),
        isTrue,
      );
      final item = sumidos.firstWhere(
        (item) => (item['cliente'] as Cliente).id == clienteId,
      );
      expect(item['diasSemVir'] as int, greaterThanOrEqualTo(59));
      expect(item['mediaIntervalo'] as int, closeTo(30, 1));
    });
  });

  // ─── GRUPO 2: AGENDA ────────────────────────────────────────────────────────

  group('Agenda', () {
    test('Cadastro e recuperação de agendamento', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Agenda',
        telefone: '11944440000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final agora = DateTime.now();
      final dataAgenda = DateTime(agora.year, agora.month, agora.day, 12, 0);

      final agendamentoId = await agendaService.insert(Agendamento(
        clienteId: clienteId,
        clienteNome: 'Cliente Agenda',
        servicoId: 1,
        servicoNome: 'Corte de Cabelo',
        dataHora: dataAgenda,
        createdAt: DateTime.now(),
        observacoes: 'Cliente pediu pontualidade',
      ));
      expect(agendamentoId, greaterThan(0));

      final agendamentosHoje = await agendaService.getDodia(DateTime.now());
      expect(agendamentosHoje.any((a) => a.id == agendamentoId), isTrue);
    });

    test('Agendamento sem cliente (avulso) funciona', () async {
      final agora = DateTime.now();
      final dataAgenda = DateTime(agora.year, agora.month, agora.day, 13, 0);
      final id = await agendaService.insert(Agendamento(
        clienteNome: 'Cliente Avulso',
        servicoId: 1,
        servicoNome: 'Barba',
        dataHora: dataAgenda,
        createdAt: DateTime.now(),
      ));
      expect(id, greaterThan(0));
    });

    test('Editar e cancelar agendamento persistem status e dados', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Agenda Edit',
        telefone: '11933334444',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final agora = DateTime.now();
      final dataAgenda = DateTime(agora.year, agora.month, agora.day, 14, 0);

      final id = await agendaService.insert(Agendamento(
        clienteId: clienteId,
        clienteNome: 'Cliente Agenda Edit',
        servicoId: 1,
        servicoNome: 'Corte de Cabelo',
        dataHora: dataAgenda,
        createdAt: DateTime.now(),
      ));

      final agendamento =
          (await agendaService.getAll()).firstWhere((a) => a.id == id);
      await agendaService.update(
        agendamento.copyWith(
          servicoNome: 'Corte + Barba',
          observacoes: 'Cliente pediu ajuste',
        ),
      );

      await agendaService.updateStatus(id, AppConstants.statusCancelado);

      final atualizado =
          (await agendaService.getAll()).firstWhere((a) => a.id == id);
      expect(atualizado.servicoNome, 'Corte + Barba');
      expect(atualizado.status, AppConstants.statusCancelado);
    });

    test('Concluir agendamento registra valor no faturamento do mês', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Agenda Faturamento',
        telefone: '11932221111',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final agora = DateTime.now();
      final dataAgenda = DateTime(agora.year, agora.month, agora.day, 15, 0);

      final id = await agendaService.insert(Agendamento(
        clienteId: clienteId,
        clienteNome: 'Cliente Agenda Faturamento',
        servicoId: 1,
        servicoNome: 'Corte de Cabelo',
        dataHora: dataAgenda,
        createdAt: DateTime.now(),
      ));

      await agendaService.updateStatus(id, AppConstants.statusConcluido);

      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final fim = DateTime.now().add(const Duration(days: 1));
      final faturamento =
          await comandaService.getFaturamentoPeriodo(inicioMes, fim);
      expect(faturamento, closeTo(35.0, 0.001));

      final concluido =
          (await agendaService.getAll()).firstWhere((a) => a.id == id);
      expect(concluido.faturamentoRegistrado, isTrue);
      expect(concluido.status, AppConstants.statusConcluido);
    });
  });

  // ─── GRUPO 3: ATENDIMENTOS ──────────────────────────────────────────────────

  group('Servicos', () {
    test('Adicionar, editar e alternar ativo/inativo funciona', () async {
      final id = await servicoService.insert(const Servico(
        nome: 'Corte Premium',
        preco: 55,
        duracaoMinutos: 40,
      ));
      expect(id, greaterThan(0));

      final criado = (await servicoService.getAll(apenasAtivos: false))
          .firstWhere((s) => s.id == id);
      expect(criado.nome, 'Corte Premium');

      await servicoService.update(
        criado.copyWith(
          nome: 'Corte Premium Gold',
          preco: 60,
        ),
      );
      final atualizado = (await servicoService.getAll(apenasAtivos: false))
          .firstWhere((s) => s.id == id);
      expect(atualizado.nome, 'Corte Premium Gold');
      expect(atualizado.preco, closeTo(60, 0.001));

      await servicoService.update(atualizado.copyWith(ativo: false));
      final inativo = (await servicoService.getAll(apenasAtivos: false))
          .firstWhere((s) => s.id == id);
      expect(inativo.ativo, isFalse);

      final ativos = await servicoService.getAll(apenasAtivos: true);
      expect(ativos.any((s) => s.id == id), isFalse);
    });

    test('Listagem de servicos mantem nomes visiveis (nao vazios)', () async {
      final lista = await servicoService.getAll(apenasAtivos: false);
      expect(lista, isNotEmpty);
      expect(lista.every((s) => s.nome.trim().isNotEmpty), isTrue);
    });
  });

  group('Barbeiros', () {
    test('Excluir barbeiro remove perfil da listagem local', () async {
      authService.setUsuarioLocalLogadoForTests(
        Usuario(
          id: 'admin_local',
          nome: 'Administrador Local',
          email: 'teste@severus.app',
          role: UserRole.admin,
          ativo: true,
          comissaoPercentual: 0,
          firstLogin: false,
          barbeariaId: AppConstants.localBarbeariaId,
          createdAt: DateTime.now(),
        ),
      );

      final barbeiro = Usuario(
        id: 'barbeiro_teste_1',
        nome: 'Barbeiro Teste',
        email: 'barbeiro.teste@severus.app',
        role: UserRole.barbeiro,
        ativo: true,
        comissaoPercentual: 50,
        firstLogin: false,
        createdAt: DateTime.now(),
      );
      await db.insert(AppConstants.tableUsuarios, barbeiro.toMap());

      final antes = await authService.listarBarbeiros(apenasAtivos: false);
      expect(antes.any((b) => b.id == barbeiro.id), isTrue);

      await authService.excluirBarbeiro(barbeiro.id);
      final depois = await authService.listarBarbeiros(apenasAtivos: false);
      expect(depois.any((b) => b.id == barbeiro.id), isFalse);
    });
  });

  group('Atendimentos', () {
    test('Registro atômico decrementa estoque e atualiza totais do cliente',
        () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Atendimento',
        telefone: '11977776666',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final produtoId = await produtoService.insert(Produto(
        nome: 'Pomada Modeladora',
        precoVenda: 30,
        precoCusto: 12,
        quantidade: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // total = 35 (corte) + 30 (pomada) = 65
      final atendimentoId = await atendimentoService.registrar(Atendimento(
        clienteId: clienteId,
        clienteNome: 'Cliente Atendimento',
        total: 65,
        formaPagamento: 'PIX',
        data: DateTime.now(),
        itens: [
          const AtendimentoItem(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte de Cabelo',
            quantidade: 1,
            precoUnitario: 35,
          ),
          AtendimentoItem(
            tipo: 'produto',
            itemId: produtoId,
            nome: 'Pomada Modeladora',
            quantidade: 1,
            precoUnitario: 30,
          ),
        ],
      ));

      expect(atendimentoId, greaterThan(0));

      final atendimento = await atendimentoService.getById(atendimentoId);
      expect(atendimento!.itens.length, 2);

      final produto = await produtoService.getById(produtoId);
      expect(produto!.quantidade, 9);

      final cliente = await clienteService.getById(clienteId);
      expect(cliente!.totalAtendimentos, 1);
      expect(cliente.totalGasto, closeTo(65, 0.001));
    });

    test('Atendimento com múltiplos produtos decrementa cada um', () async {
      final p1 = await produtoService.insert(Produto(
        nome: 'Gel Fixador',
        precoVenda: 20,
        precoCusto: 8,
        quantidade: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final p2 = await produtoService.insert(Produto(
        nome: 'Shampoo',
        precoVenda: 18,
        precoCusto: 7,
        quantidade: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // total = 2*20 + 1*18 = 58
      await atendimentoService.registrar(Atendimento(
        clienteNome: 'Avulso',
        total: 58,
        formaPagamento: 'Dinheiro',
        data: DateTime.now(),
        itens: [
          AtendimentoItem(
              tipo: 'produto',
              itemId: p1,
              nome: 'Gel Fixador',
              quantidade: 2,
              precoUnitario: 20),
          AtendimentoItem(
              tipo: 'produto',
              itemId: p2,
              nome: 'Shampoo',
              quantidade: 1,
              precoUnitario: 18),
        ],
      ));

      final produto1 = await produtoService.getById(p1);
      final produto2 = await produtoService.getById(p2);
      expect(produto1!.quantidade, 3);
      expect(produto2!.quantidade, 2);
    });
  });

  // ─── GRUPO 4: COMANDAS ──────────────────────────────────────────────────────

  group('Comandas', () {
    test('Fluxo completo: abrir → adicionar → fechar', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'Cliente Comanda',
        telefone: '11966665555',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final produtoId = await produtoService.insert(Produto(
        nome: 'Gel Fixador',
        precoVenda: 20,
        precoCusto: 8,
        quantidade: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final comanda = await comandaService.abrirComanda(
        clienteId: clienteId,
        clienteNome: 'Cliente Comanda',
        barbeiroId: 'barbeiro_1',
        barbeiroNome: 'Barbeiro Teste',
      );

      // comissaoPercentual usa escala 0.0 – 1.0
      await comandaService.adicionarItem(
          comanda.id!,
          const ItemComanda(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte de Cabelo',
            quantidade: 1,
            precoUnitario: 35,
            comissaoPercentual: 0.5,
          ));
      await comandaService.adicionarItem(
          comanda.id!,
          ItemComanda(
            tipo: 'produto',
            itemId: produtoId,
            nome: 'Gel Fixador',
            quantidade: 2,
            precoUnitario: 20,
            comissaoPercentual: 0.2,
          ));

      await comandaService.fecharComanda(
        comandaId: comanda.id!,
        formaPagamento: 'Dinheiro',
      );

      final fechada = await comandaService.getById(comanda.id!);
      expect(fechada!.status, 'fechada');
      expect(fechada.total, closeTo(75, 0.001));

      final produto = await produtoService.getById(produtoId);
      expect(produto!.quantidade, 2);

      final cliente = await clienteService.getById(clienteId);
      expect(cliente!.totalGasto, closeTo(75, 0.001));
    });

    test('Fechar comanda sem itens deve lançar ValidationException', () async {
      final comanda = await comandaService.abrirComanda(
        clienteNome: 'Sem Itens',
      );

      expect(
        () => comandaService.fecharComanda(
          comandaId: comanda.id!,
          formaPagamento: 'PIX',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Adicionar item em comanda fechada lança ConflictException', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'CC Fechada',
        telefone: '11966665555',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final produtoId = await produtoService.insert(Produto(
        nome: 'Gel Fixador',
        precoVenda: 20,
        precoCusto: 8,
        quantidade: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final comanda = await comandaService.abrirComanda(
        clienteId: clienteId,
        clienteNome: 'CC Fechada',
      );
      await comandaService.adicionarItem(
          comanda.id!,
          ItemComanda(
            tipo: 'produto',
            itemId: produtoId,
            nome: 'Gel Fixador',
            quantidade: 1,
            precoUnitario: 20,
            comissaoPercentual: 0.2,
          ));

      await comandaService.fecharComanda(
        comandaId: comanda.id!,
        formaPagamento: 'Dinheiro',
      );

      expect(
        () => comandaService.adicionarItem(
          comanda.id!,
          const ItemComanda(
            tipo: 'servico',
            itemId: 1,
            nome: 'Barba',
            quantidade: 1,
            precoUnitario: 25,
            comissaoPercentual: 0.5,
          ),
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('Cancelar comanda aberta funciona corretamente', () async {
      final comanda =
          await comandaService.abrirComanda(clienteNome: 'Cancelado');
      await comandaService.cancelarComanda(comanda.id!);

      final cancelada = await comandaService.getById(comanda.id!);
      expect(cancelada!.status, 'cancelada');
    });

    test('Cancelar comanda fechada lança ConflictException', () async {
      final clienteId = await clienteService.insert(Cliente(
        nome: 'CC Cancel Test',
        telefone: '11911112222',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final produtoId = await produtoService.insert(Produto(
        nome: 'Prod Cancel',
        precoVenda: 20,
        precoCusto: 8,
        quantidade: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final comanda = await comandaService.abrirComanda(
        clienteId: clienteId,
        clienteNome: 'CC Cancel Test',
      );
      await comandaService.adicionarItem(
          comanda.id!,
          ItemComanda(
            tipo: 'produto',
            itemId: produtoId,
            nome: 'Prod Cancel',
            quantidade: 1,
            precoUnitario: 20,
            comissaoPercentual: 0.2,
          ));
      await comandaService.fecharComanda(
        comandaId: comanda.id!,
        formaPagamento: 'PIX',
      );

      expect(
        () => comandaService.cancelarComanda(comanda.id!),
        throwsA(isA<ConflictException>()),
      );
    });

    test('Faturamento barbeiro calculado corretamente', () async {
      final comanda = await comandaService.abrirComanda(
        clienteNome: 'Faturamento Test',
        barbeiroId: 'barb_test',
        barbeiroNome: 'Barb Test',
      );
      await comandaService.adicionarItem(
          comanda.id!,
          const ItemComanda(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte de Cabelo',
            quantidade: 1,
            precoUnitario: 40,
            comissaoPercentual: 0.5,
          ));
      await comandaService.fecharComanda(
        comandaId: comanda.id!,
        formaPagamento: 'PIX',
      );

      final inicio = DateTime.now().subtract(const Duration(hours: 1));
      final fim = DateTime.now().add(const Duration(hours: 1));
      final fat =
          await comandaService.getFaturamentoBarbeiro('barb_test', inicio, fim);
      expect(fat, closeTo(40, 0.001));
    });

    test('Ranking de barbeiros retorna resultado correto', () async {
      final comanda = await comandaService.abrirComanda(
        clienteNome: 'Ranking Test',
        barbeiroId: 'barb_rank',
        barbeiroNome: 'Barb Rank',
      );
      await comandaService.adicionarItem(
          comanda.id!,
          const ItemComanda(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte de Cabelo',
            quantidade: 1,
            precoUnitario: 60,
            comissaoPercentual: 0.5,
          ));
      await comandaService.fecharComanda(
        comandaId: comanda.id!,
        formaPagamento: 'Dinheiro',
      );

      final inicio = DateTime.now().subtract(const Duration(hours: 1));
      final fim = DateTime.now().add(const Duration(hours: 1));
      final ranking = await comandaService.getRankingBarbeiros(inicio, fim);
      expect(ranking.any((r) => r['barbeiro_id'] == 'barb_rank'), isTrue);
    });
  });

  // ─── GRUPO 5: ESTOQUE ───────────────────────────────────────────────────────

  group('Estoque', () {
    test('Concorrência: apenas 1 venda bem-sucedida quando há saldo para 1',
        () async {
      final produtoId = await produtoService.insert(Produto(
        nome: 'Shampoo Premium',
        precoVenda: 18,
        precoCusto: 7,
        quantidade: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final clienteA = await clienteService.insert(Cliente(
        nome: 'Cliente A',
        telefone: '11955554444',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final clienteB = await clienteService.insert(Cliente(
        nome: 'Cliente B',
        telefone: '11944443333',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      Future<bool> tentarRegistrar(int clienteId, String nome) async {
        try {
          await atendimentoService.registrar(Atendimento(
            clienteId: clienteId,
            clienteNome: nome,
            total: 54, // 3 × 18
            formaPagamento: 'PIX',
            data: DateTime.now(),
            itens: [
              AtendimentoItem(
                tipo: 'produto',
                itemId: produtoId,
                nome: 'Shampoo Premium',
                quantidade: 3,
                precoUnitario: 18,
              ),
            ],
          ));
          return true;
        } catch (_) {
          return false;
        }
      }

      final resultados = await Future.wait([
        tentarRegistrar(clienteA, 'Cliente A'),
        tentarRegistrar(clienteB, 'Cliente B'),
      ]);

      final sucesso = resultados.where((r) => r).length;
      final falha = resultados.where((r) => !r).length;
      expect(sucesso, 1);
      expect(falha, 1);

      final produto = await produtoService.getById(produtoId);
      expect(produto!.quantidade, 2);
    });

    test('Entrada de estoque atualiza quantidade e custo médio', () async {
      final produtoId = await produtoService.insert(Produto(
        nome: 'Óleo Capilar',
        precoVenda: 40,
        precoCusto: 15,
        quantidade: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await produtoService.entradaEstoque(
        produtoId: produtoId,
        quantidade: 5,
        valorUnitario: 17,
        observacao: 'Reposição',
      );

      final produto = await produtoService.getById(produtoId);
      expect(produto!.quantidade, 10);
      expect(produto.precoCusto,
          closeTo(16.0, 0.01)); // custo médio = (5*15 + 5*17)/10
    });

    test('Saída maior que estoque lança ConflictException', () async {
      final produtoId = await produtoService.insert(Produto(
        nome: 'Produto Escasso',
        precoVenda: 25,
        precoCusto: 10,
        quantidade: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(
        () => produtoService.baixarEstoque(
          produtoId: produtoId,
          quantidade: 5,
          valorUnitario: 25,
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test('getProdutosEstoqueBaixo retorna produto abaixo do mínimo', () async {
      final produtoId = await produtoService.insert(Produto(
        nome: 'Produto Baixo',
        precoVenda: 30,
        precoCusto: 12,
        quantidade: 1,
        estoqueMinimo: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final baixo = await produtoService.getProdutosEstoqueBaixo();
      expect(baixo.any((p) => p.id == produtoId), isTrue);
    });
  });

  // ─── GRUPO 6: FINANCEIRO ────────────────────────────────────────────────────

  group('Financeiro — Despesas', () {
    test('Inserção e recuperação de despesa', () async {
      final id = await financeiroService.insertDespesa(Despesa(
        descricao: 'Aluguel Julho',
        categoria: 'Aluguel',
        valor: 1500.0,
        data: DateTime.now(),
      ));
      expect(id, greaterThan(0));

      final lista = await financeiroService.getDespesas();
      expect(lista.any((d) => d.id == id && d.valor == 1500.0), isTrue);
    });

    test('Atualização de despesa persiste corretamente', () async {
      final id = await financeiroService.insertDespesa(Despesa(
        descricao: 'Internet',
        categoria: 'Internet',
        valor: 100.0,
        data: DateTime.now(),
      ));

      final despesa =
          (await financeiroService.getDespesas()).firstWhere((d) => d.id == id);
      await financeiroService.updateDespesa(despesa.copyWith(valor: 120.0));

      final atualizada =
          (await financeiroService.getDespesas()).firstWhere((d) => d.id == id);
      expect(atualizada.valor, closeTo(120.0, 0.001));
    });

    test('Exclusão de despesa remove do banco', () async {
      final id = await financeiroService.insertDespesa(Despesa(
        descricao: 'Manutenção AC',
        categoria: 'Manutenção',
        valor: 250.0,
        data: DateTime.now(),
      ));

      await financeiroService.deleteDespesa(id);
      final lista = await financeiroService.getDespesas();
      expect(lista.any((d) => d.id == id), isFalse);
    });

    test('getTotalDespesas soma corretamente no período', () async {
      final hoje = DateTime.now();
      final inicio = DateTime(hoje.year, hoje.month, hoje.day);
      final fim = inicio.add(const Duration(days: 1));

      await financeiroService.insertDespesa(Despesa(
          descricao: 'Energia',
          categoria: 'Energia Elétrica',
          valor: 300.0,
          data: hoje));
      await financeiroService.insertDespesa(Despesa(
          descricao: 'Água', categoria: 'Água', valor: 80.0, data: hoje));

      final total = await financeiroService.getTotalDespesas(inicio, fim);
      expect(total, closeTo(380.0, 0.001));
    });

    test('getResumo calcula lucro como faturamento menos despesas', () async {
      final hoje = DateTime.now();
      final inicio = DateTime(hoje.year, hoje.month, hoje.day);
      final fim = inicio.add(const Duration(days: 1));

      // Cria comanda para gerar faturamento de R$ 100.
      final comanda =
          await comandaService.abrirComanda(clienteNome: 'Resumo Test');
      await comandaService.adicionarItem(
          comanda.id!,
          const ItemComanda(
            tipo: 'servico',
            itemId: 1,
            nome: 'Corte',
            quantidade: 1,
            precoUnitario: 100,
            comissaoPercentual: 0.5,
          ));
      await comandaService.fecharComanda(
          comandaId: comanda.id!, formaPagamento: 'Dinheiro');

      await financeiroService.insertDespesa(Despesa(
          descricao: 'Despesa Resumo',
          categoria: 'Outros',
          valor: 30.0,
          data: hoje));

      final resumo = await financeiroService.getResumo(inicio, fim);
      expect(resumo['faturamento'], closeTo(100.0, 0.001));
      expect(resumo['despesas'], closeTo(30.0, 0.001));
      expect(resumo['lucro'], closeTo(70.0, 0.001));
    });
  });

  group('Financeiro — Caixa', () {
    test('Abrir e fechar caixa funciona corretamente', () async {
      final caixaId = await financeiroService.abrirCaixa(valorInicial: 100.0);
      expect(caixaId, greaterThan(0));

      final aberto = await financeiroService.getCaixaAberto();
      expect(aberto, isNotNull);
      expect(aberto!.valorInicial, closeTo(100.0, 0.001));

      await financeiroService.fecharCaixa(caixaId);

      final fechado = await financeiroService.getCaixaAberto();
      expect(fechado, isNull);
    });

    test('Tentar abrir segundo caixa lança ConflictException', () async {
      await financeiroService.abrirCaixa(valorInicial: 50.0);

      expect(
        () => financeiroService.abrirCaixa(valorInicial: 50.0),
        throwsA(isA<ConflictException>()),
      );
    });

    test('Sangria de caixa cria despesa interna', () async {
      final caixaId = await financeiroService.abrirCaixa(valorInicial: 500.0);

      await financeiroService.sangria(
        caixaId: caixaId,
        valor: 100.0,
        observacao: 'Pagamento fornecedor',
      );

      final despesas = await financeiroService.getDespesas();
      expect(despesas.any((d) => d.valor == 100.0), isTrue);
    });

    test('Reforço de caixa aumenta valor inicial', () async {
      final caixaId = await financeiroService.abrirCaixa(valorInicial: 200.0);

      await financeiroService.reforco(
        caixaId: caixaId,
        valor: 100.0,
        observacao: 'Troco extra',
      );

      final caixa = await financeiroService.getCaixaAberto();
      expect(caixa!.valorInicial, closeTo(300.0, 0.001));
    });
  });

  // ─── GRUPO 7: MODELOS ───────────────────────────────────────────────────────

  group('Modelos — serialização', () {
    test('Caixa.toMap / fromMap são equivalentes', () {
      final c = Caixa(
        id: 1,
        dataAbertura: DateTime(2025, 1, 1, 9, 0),
        valorInicial: 50.0,
        status: 'aberto',
      );
      final mapa = c.toMap();
      final restaurado = Caixa.fromMap({...mapa, 'id': 1});
      expect(restaurado.valorInicial, c.valorInicial);
      expect(restaurado.status, c.status);
    });

    test('Despesa.toMap / fromMap são equivalentes', () {
      final d = Despesa(
        descricao: 'Luz',
        categoria: 'Energia Elétrica',
        valor: 200.0,
        data: DateTime(2025, 6, 1),
      );
      final mapa = d.toMap();
      final restaurado = Despesa.fromMap({...mapa, 'id': null});
      expect(restaurado.valor, d.valor);
      expect(restaurado.categoria, d.categoria);
    });
  });
}
