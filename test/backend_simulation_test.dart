import 'package:barbearia_pro/database/database_helper.dart';
import 'package:barbearia_pro/models/agendamento.dart';
import 'package:barbearia_pro/models/atendimento.dart';
import 'package:barbearia_pro/models/cliente.dart';
import 'package:barbearia_pro/models/item_comanda.dart';
import 'package:barbearia_pro/models/produto.dart';
import 'package:barbearia_pro/services/agenda_service.dart';
import 'package:barbearia_pro/services/atendimento_service.dart';
import 'package:barbearia_pro/services/cliente_service.dart';
import 'package:barbearia_pro/services/comanda_service.dart';
import 'package:barbearia_pro/services/produto_service.dart';
import 'package:barbearia_pro/services/service_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final db = DatabaseHelper();
  final clienteService = ClienteService();
  final agendaService = AgendaService();
  final atendimentoService = AtendimentoService();
  final comandaService = ComandaService();
  final produtoService = ProdutoService();

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

  test('Cadastro de cliente e agendamento devem funcionar com UTF-8', () async {
    final clienteId = await clienteService.insert(
      Cliente(
        nome: 'João da Silva Filho',
        telefone: '(11) 98888-7777',
        observacoes: 'Prefere atendimento no fim da tarde e sábado',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    expect(clienteId, greaterThan(0));

    final cliente = await clienteService.getById(clienteId);
    expect(cliente, isNotNull);
    expect(cliente!.nome, 'João da Silva Filho');

    final agendamentoId = await agendaService.insert(
      Agendamento(
        clienteId: clienteId,
        clienteNome: cliente.nome,
        servicoId: 1,
        servicoNome: 'Corte de Cabelo',
        dataHora: DateTime.now().add(const Duration(hours: 2)),
        createdAt: DateTime.now(),
        observacoes: 'Cliente pediu pontualidade',
      ),
    );
    expect(agendamentoId, greaterThan(0));

    final agendamentosHoje = await agendaService.getDodia(DateTime.now());
    expect(
      agendamentosHoje.any((a) => a.id == agendamentoId),
      isTrue,
    );
  });

  test('Registro de atendimento deve ser atomico', () async {
    final clienteId = await clienteService.insert(
      Cliente(
        nome: 'Cliente Atendimento',
        telefone: '(11) 97777-6666',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final produtoId = await produtoService.insert(
      Produto(
        nome: 'Pomada Modeladora',
        precoVenda: 30,
        precoCusto: 12,
        quantidade: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final atendimentoId = await atendimentoService.registrar(
      Atendimento(
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
      ),
    );

    expect(atendimentoId, greaterThan(0));

    final atendimento = await atendimentoService.getById(atendimentoId);
    expect(atendimento, isNotNull);
    expect(atendimento!.itens.length, 2);

    final produto = await produtoService.getById(produtoId);
    expect(produto, isNotNull);
    expect(produto!.quantidade, 9);

    final cliente = await clienteService.getById(clienteId);
    expect(cliente, isNotNull);
    expect(cliente!.totalAtendimentos, 1);
    expect(cliente.totalGasto, closeTo(65, 0.001));
  });

  test('Fluxo de comanda deve impedir alteracao apos fechamento', () async {
    final clienteId = await clienteService.insert(
      Cliente(
        nome: 'Cliente Comanda',
        telefone: '(11) 96666-5555',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final produtoId = await produtoService.insert(
      Produto(
        nome: 'Gel Fixador',
        precoVenda: 20,
        precoCusto: 8,
        quantidade: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final comanda = await comandaService.abrirComanda(
      clienteId: clienteId,
      clienteNome: 'Cliente Comanda',
      barbeiroId: 'barbeiro_1',
      barbeiroNome: 'Barbeiro Teste',
    );

    await comandaService.adicionarItem(
      comanda.id!,
      const ItemComanda(
        tipo: 'servico',
        itemId: 1,
        nome: 'Corte de Cabelo',
        quantidade: 1,
        precoUnitario: 35,
        comissaoPercentual: 0.5,
      ),
    );
    await comandaService.adicionarItem(
      comanda.id!,
      ItemComanda(
        tipo: 'produto',
        itemId: produtoId,
        nome: 'Gel Fixador',
        quantidade: 2,
        precoUnitario: 20,
        comissaoPercentual: 0.2,
      ),
    );

    await comandaService.fecharComanda(
      comandaId: comanda.id!,
      formaPagamento: 'Dinheiro',
    );

    final fechada = await comandaService.getById(comanda.id!);
    expect(fechada, isNotNull);
    expect(fechada!.status, 'fechada');
    expect(fechada.total, closeTo(75, 0.001));

    final produto = await produtoService.getById(produtoId);
    expect(produto, isNotNull);
    expect(produto!.quantidade, 2);

    final cliente = await clienteService.getById(clienteId);
    expect(cliente, isNotNull);
    expect(cliente!.totalAtendimentos, 1);
    expect(cliente.totalGasto, closeTo(75, 0.001));

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

  test(
      'Concorrencia no estoque deve permitir apenas uma venda quando faltar saldo',
      () async {
    final produtoId = await produtoService.insert(
      Produto(
        nome: 'Shampoo Premium',
        precoVenda: 18,
        precoCusto: 7,
        quantidade: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final clienteA = await clienteService.insert(
      Cliente(
        nome: 'Cliente A',
        telefone: '(11) 95555-4444',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final clienteB = await clienteService.insert(
      Cliente(
        nome: 'Cliente B',
        telefone: '(11) 94444-3333',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    Future<bool> tentarRegistrar(int clienteId, String nome) async {
      try {
        await atendimentoService.registrar(
          Atendimento(
            clienteId: clienteId,
            clienteNome: nome,
            total: 54,
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
          ),
        );
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
    expect(produto, isNotNull);
    expect(produto!.quantidade, 2);

    final atendimentos = await atendimentoService.getAll();
    expect(atendimentos.length, 1);
  });
}
