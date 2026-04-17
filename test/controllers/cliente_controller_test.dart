import 'package:barbearia_pro/controllers/cliente_controller.dart';
import 'package:barbearia_pro/models/cliente.dart';
import 'package:barbearia_pro/services/cliente_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClienteService extends ClienteService {
  _FakeClienteService(this._data);

  final List<Cliente> _data;
  bool falharInsert = false;

  @override
  Future<List<Cliente>> getAll() async => List<Cliente>.from(_data);

  @override
  Stream<List<Cliente>> streamClientes() async* {
    yield List<Cliente>.from(_data);
  }

  @override
  Future<List<Cliente>> search(String query) async {
    final q = query.trim().toLowerCase();
    return _data
        .where((c) =>
            c.nome.toLowerCase().contains(q) || c.telefone.contains(query))
        .toList(growable: false);
  }

  @override
  Future<int> insert(Cliente cliente) async {
    if (falharInsert) throw Exception('Falha simulada ao inserir');
    final novoId =
        (_data.map((c) => c.id ?? 0).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    _data.add(cliente.copyWith(id: novoId));
    return novoId;
  }

  @override
  Future<void> update(Cliente cliente) async {
    final i = _data.indexWhere((c) => c.id == cliente.id);
    if (i >= 0) _data[i] = cliente;
  }

  @override
  Future<void> delete(int id) async {
    _data.removeWhere((c) => c.id == id);
  }
}

Cliente _cliente({
  required int id,
  required String nome,
  required String telefone,
}) {
  final now = DateTime(2026, 4, 17);
  return Cliente(
    id: id,
    nome: nome,
    telefone: telefone,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('carregar popula lista e filtrados', () async {
    final fake = _FakeClienteService([
      _cliente(id: 1, nome: 'Joao', telefone: '11999990001'),
      _cliente(id: 2, nome: 'Maria', telefone: '11999990002'),
    ]);
    final controller = ClienteController(clienteService: fake);

    await controller.carregar();

    expect(controller.clientes.length, 2);
    expect(controller.clientesFiltrados.length, 2);
    expect(controller.errorMsg, isNull);
  });

  test('buscar filtra clientes corretamente', () async {
    final fake = _FakeClienteService([
      _cliente(id: 1, nome: 'Carlos', telefone: '11999990001'),
      _cliente(id: 2, nome: 'Fernanda', telefone: '11999990002'),
    ]);
    final controller = ClienteController(clienteService: fake);
    await controller.carregar();

    await controller.buscar('car');

    expect(controller.clientesFiltrados.length, 1);
    expect(controller.clientesFiltrados.first.nome, 'Carlos');
  });

  test('erro em salvar preenche errorMsg', () async {
    final fake = _FakeClienteService([]);
    fake.falharInsert = true;
    final controller = ClienteController(clienteService: fake);

    final now = DateTime(2026, 4, 17);
    final novo = Cliente(
      nome: 'Novo Cliente',
      telefone: '11999990003',
      createdAt: now,
      updatedAt: now,
    );

    await expectLater(controller.salvar(novo), throwsException);
    expect(controller.errorMsg, contains('Falha simulada ao inserir'));
  });
}
