import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../controllers/agenda_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cliente_controller.dart';
import '../../controllers/servico_controller.dart';
import '../../models/agendamento.dart';
import '../../models/cliente.dart';
import '../../models/servico.dart';
import '../../models/usuario.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  AgendaController get _agendaController => context.read<AgendaController>();
  ClienteController get _clienteController => context.read<ClienteController>();
  ServicoController get _servicoController => context.read<ServicoController>();

  List<Agendamento> _agendamentos = [];
  List<Usuario> _barbeiros = [];
  DateTime _diaSelecionado = DateTime.now();
  DateTime _foco = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final authController = context.read<AuthController>();
      final isAdmin = authController.isAdmin;
      final results = await Future.wait([
        _agendaController.getAll(),
        isAdmin
            ? authController.listarBarbeiros(apenasAtivos: true)
            : Future.value(<Usuario>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _agendamentos = results[0] as List<Agendamento>;
        _barbeiros = results[1] as List<Usuario>;
      });
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao carregar agenda: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Agendamento> _eventosDia(DateTime day) {
    final eventos = _agendamentos.where((agendamento) {
      final data = agendamento.dataHora;
      return data.year == day.year &&
          data.month == day.month &&
          data.day == day.day;
    }).toList();
    eventos.sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return eventos;
  }

  Color _corStatus(String status) {
    if (status == AppConstants.statusPendente) return AppTheme.warningColor;
    if (status == AppConstants.statusConfirmado) return AppTheme.infoColor;
    if (status == AppConstants.statusConcluido) return AppTheme.successColor;
    if (status == AppConstants.statusCancelado) return AppTheme.errorColor;
    return AppTheme.textSecondary;
  }

  Future<void> _alterarStatus(Agendamento agendamento) async {
    var status = agendamento.status;
    final salvar = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atualizar status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Novo status',
                    ),
                    items: AppConstants.statusAgendamento
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Salvar status'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (salvar != true || agendamento.id == null) return;
    String? formaPagamento;
    if (status == AppConstants.statusConcluido) {
      formaPagamento = await _selecionarFormaPagamento();
      if (formaPagamento == null) return;
    }
    try {
      await _agendaController.updateStatus(
        agendamento.id!,
        status,
        formaPagamento: formaPagamento,
      );
      if (mounted) {
        UiFeedback.showSnack(
          context,
          status == AppConstants.statusConcluido
              ? 'Status atualizado e faturamento registrado.'
              : 'Status atualizado com sucesso.',
          type: AppNoticeType.success,
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao atualizar status: $e',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<String?> _selecionarFormaPagamento() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forma de pagamento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...AppConstants.formasPagamento.map(
                  (forma) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      forma == AppConstants.pgDinheiro
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: forma == AppConstants.pgDinheiro
                          ? AppTheme.accentColor
                          : null,
                    ),
                    title: Text(forma),
                    onTap: () => Navigator.pop(ctx, forma),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelarAgendamento(Agendamento agendamento) async {
    if (agendamento.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar agendamento'),
        content: Text(
            'Deseja cancelar o agendamento de ${agendamento.clienteNome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    try {
      await _agendaController.updateStatus(
          agendamento.id!, AppConstants.statusCancelado);
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Agendamento cancelado.',
          type: AppNoticeType.success,
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao cancelar agendamento: $e',
          type: AppNoticeType.error,
        );
      }
    }
  }

  Future<void> _abrirFormulario({Agendamento? existente}) async {
    final buscaClienteCtrl =
        TextEditingController(text: existente?.clienteNome ?? '');
    final obsCtrl = TextEditingController(text: existente?.observacoes ?? '');

    Cliente? cliente;
    Servico? servico;
    Usuario? barbeiroSelecionado;
    DateTime dataHora =
        existente?.dataHora ?? DateTime.now().add(const Duration(hours: 1));
    List<Cliente> sugestoes = [];
    late final List<Servico> servicos;

    final auth = context.read<AuthController>();
    final admin = auth.isAdmin;

    try {
      servicos = await _servicoController.getAll(apenasAtivos: true);
      if (servicos.isEmpty) {
        if (mounted) {
          UiFeedback.showSnack(
            context,
            'Cadastre ao menos um serviço ativo antes de agendar.',
            type: AppNoticeType.error,
          );
        }
        return;
      }

      if (admin && _barbeiros.isEmpty) {
        _barbeiros = await auth.listarBarbeiros(apenasAtivos: true);
      }

      if (existente?.clienteId != null) {
        cliente = await _clienteController.getById(existente!.clienteId!);
      }

      if (existente?.servicoId != null) {
        for (final item in servicos) {
          if (item.id == existente!.servicoId) {
            servico = item;
            break;
          }
        }
      }
      servico ??= servicos.first;

      if (admin) {
        if (existente?.barbeiroId != null) {
          for (final b in _barbeiros) {
            if (b.id == existente!.barbeiroId) {
              barbeiroSelecionado = b;
              break;
            }
          }
        }
        barbeiroSelecionado ??= _barbeiros.isNotEmpty ? _barbeiros.first : null;
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao carregar dados de agendamento: $e',
          type: AppNoticeType.error,
        );
      }
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    if (!mounted) {
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final nomeDigitado = buscaClienteCtrl.text.trim();
            final podeSalvar = (cliente != null ||
                    nomeDigitado.isNotEmpty ||
                    ((existente?.clienteNome.trim().isNotEmpty) ?? false)) &&
                servico != null &&
                (!admin || barbeiroSelecionado != null);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existente == null
                          ? 'Novo agendamento'
                          : 'Editar agendamento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: buscaClienteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar cliente',
                        hintText: 'Digite ao menos 2 letras',
                      ),
                      onChanged: (value) async {
                        final query = value.trim();
                        if (query.length < 2) {
                          setModalState(() => sugestoes = []);
                          return;
                        }
                        final resultados =
                            await _clienteController.search(query);
                        setModalState(() => sugestoes = resultados);
                      },
                    ),
                    const SizedBox(height: 6),
                    if (cliente != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Cliente selecionado: ${cliente!.nome}',
                          style: const TextStyle(color: AppTheme.successColor),
                        ),
                      ),
                    if (sugestoes.isNotEmpty)
                      ...sugestoes.take(5).map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.nome),
                              subtitle: Text(item.telefone),
                              onTap: () {
                                setModalState(() {
                                  cliente = item;
                                  buscaClienteCtrl.text = item.nome;
                                  sugestoes = [];
                                });
                              },
                            ),
                          ),
                    DropdownButtonFormField<Servico>(
                      initialValue: servico,
                      decoration: const InputDecoration(labelText: 'Serviço'),
                      items: servicos
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                '${item.nome} (${AppFormatters.currency(item.preco)})',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setModalState(() => servico = value),
                    ),
                    if (admin) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Usuario>(
                        initialValue: barbeiroSelecionado,
                        decoration:
                            const InputDecoration(labelText: 'Barbeiro'),
                        items: _barbeiros
                            .map(
                              (item) => DropdownMenuItem<Usuario>(
                                value: item,
                                child: Text(item.nome),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setModalState(() => barbeiroSelecionado = value),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data e hora'),
                      subtitle: Text(AppFormatters.dateTime(dataHora)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final data = await showDatePicker(
                          context: ctx,
                          initialDate: dataHora,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (data == null || !ctx.mounted) return;
                        final hora = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(dataHora),
                        );
                        if (hora == null) return;
                        setModalState(() {
                          dataHora = DateTime(
                            data.year,
                            data.month,
                            data.day,
                            hora.hour,
                            hora.minute,
                          );
                        });
                      },
                    ),
                    TextField(
                      controller: obsCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Observações'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            podeSalvar ? () => Navigator.pop(ctx, true) : null,
                        icon: const Icon(Icons.save),
                        label: Text(
                          existente == null
                              ? 'Salvar agendamento'
                              : 'Atualizar agendamento',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (salvar != true) {
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    if (!mounted) {
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    final servicoSelecionado = servico;
    if (servicoSelecionado == null) {
      UiFeedback.showSnack(
        context,
        'Selecione um serviço para continuar.',
        type: AppNoticeType.error,
      );
      return;
    }

    final nomeDigitado = buscaClienteCtrl.text.trim();
    final clienteNome = cliente?.nome ??
        (nomeDigitado.isNotEmpty
            ? nomeDigitado
            : (existente?.clienteNome ?? ''));
    if (clienteNome.trim().isEmpty) {
      UiFeedback.showSnack(
        context,
        'Selecione um cliente para continuar.',
        type: AppNoticeType.error,
      );
      return;
    }

    final barbeiroId = admin
        ? barbeiroSelecionado?.id
        : (existente?.barbeiroId ?? auth.usuarioId);
    final barbeiroNome = admin
        ? barbeiroSelecionado?.nome
        : (existente?.barbeiroNome ?? auth.usuarioNome);

    if (admin && (barbeiroId == null || barbeiroNome == null)) {
      UiFeedback.showSnack(
        context,
        'Selecione um barbeiro para continuar.',
        type: AppNoticeType.error,
      );
      return;
    }

    try {
      final payload = Agendamento(
        id: existente?.id,
        clienteId: cliente?.id ?? existente?.clienteId,
        clienteNome: clienteNome,
        servicoId: servicoSelecionado.id,
        servicoNome: servicoSelecionado.nome,
        barbeiroId: barbeiroId,
        barbeiroNome: barbeiroNome,
        dataHora: dataHora,
        status: existente?.status ?? AppConstants.statusPendente,
        faturamentoRegistrado: existente?.faturamentoRegistrado ?? false,
        observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        createdAt: existente?.createdAt ?? DateTime.now(),
      );

      if (existente == null) {
        await _agendaController.insert(payload);
      } else {
        await _agendaController.update(payload);
      }

      if (mounted) {
        UiFeedback.showSnack(
          context,
          existente == null
              ? 'Agendamento criado com sucesso.'
              : 'Agendamento atualizado com sucesso.',
          type: AppNoticeType.success,
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          existente == null
              ? 'Falha ao criar agendamento: $e'
              : 'Falha ao atualizar agendamento: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
    }
  }

  Future<void> _novoAgendamento() => _abrirFormulario();

  Future<void> _editarAgendamento(Agendamento agendamento) async {
    await _abrirFormulario(existente: agendamento);
  }

  Future<void> _abrirAcoesAgendamento(Agendamento agendamento) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: AppTheme.infoColor),
                title: const Text('Editar agendamento'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _editarAgendamento(agendamento);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.sync_alt, color: AppTheme.warningColor),
                title: const Text('Alterar status'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _alterarStatus(agendamento);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined,
                    color: AppTheme.errorColor),
                title: const Text('Cancelar agendamento'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _cancelarAgendamento(agendamento);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosSelecionados = _eventosDia(_diaSelecionado);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Ir para hoje',
            onPressed: () {
              setState(() {
                _diaSelecionado = DateTime.now();
                _foco = DateTime.now();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      drawer: const AppDrawer(selectedItem: AppDrawer.agenda),
      floatingActionButton: eventosSelecionados.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _novoAgendamento,
              icon: const Icon(Icons.add),
              label: const Text('Novo agendamento'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AppPageContainer(
              child: Column(
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: TableCalendar<Agendamento>(
                      locale: 'pt_BR',
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2035),
                      focusedDay: _foco,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _diaSelecionado),
                      eventLoader: _eventosDia,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _diaSelecionado = selectedDay;
                          _foco = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _foco = focusedDay);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(
                          '${eventosSelecionados.length} compromisso(s) no dia',
                        ),
                      ),
                      _buildLegendaChip(
                        AppConstants.statusPendente,
                        _corStatus(AppConstants.statusPendente),
                      ),
                      _buildLegendaChip(
                        AppConstants.statusConfirmado,
                        _corStatus(AppConstants.statusConfirmado),
                      ),
                      _buildLegendaChip(
                        AppConstants.statusConcluido,
                        _corStatus(AppConstants.statusConcluido),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: eventosSelecionados.isEmpty
                        ? AppEmptyState(
                            icon: Icons.event_busy,
                            title: 'Nenhum agendamento neste dia',
                            subtitle:
                                'Crie um novo agendamento para organizar a agenda.',
                            actionLabel: 'Novo agendamento',
                            onAction: _novoAgendamento,
                          )
                        : ListView.builder(
                            itemCount: eventosSelecionados.length,
                            itemBuilder: (context, index) {
                              final agendamento = eventosSelecionados[index];
                              final barbeiroLabel = (agendamento.barbeiroNome ==
                                          null ||
                                      agendamento.barbeiroNome!.trim().isEmpty)
                                  ? ''
                                  : ' • ${agendamento.barbeiroNome}';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () =>
                                      _abrirAcoesAgendamento(agendamento),
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoColor
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppFormatters.time(agendamento.dataHora),
                                      style: const TextStyle(
                                        color: AppTheme.infoColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  title: Text(agendamento.clienteNome),
                                  subtitle: Text(
                                    '${agendamento.servicoNome}$barbeiroLabel',
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _corStatus(agendamento.status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      agendamento.status,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLegendaChip(String label, Color color) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
    );
  }
}
