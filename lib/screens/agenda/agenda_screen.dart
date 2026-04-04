import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/agendamento.dart';
import '../../models/cliente.dart';
import '../../models/servico.dart';
import '../../services/agenda_service.dart';
import '../../services/cliente_service.dart';
import '../../services/servico_service.dart';
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
  final AgendaService _agendaService = AgendaService();
  final ClienteService _clienteService = ClienteService();
  final ServicoService _servicoService = ServicoService();

  List<Agendamento> _agendamentos = [];
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
      _agendamentos = await _agendaService.getAll();
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
    try {
      await _agendaService.updateStatus(agendamento.id!, status);
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Status atualizado com sucesso.',
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

  Future<void> _novoAgendamento() async {
    final buscaClienteCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    Cliente? cliente;
    Servico? servico;
    DateTime dataHora = DateTime.now().add(const Duration(hours: 1));
    List<Cliente> sugestoes = [];
    late final List<Servico> servicos;

    try {
      servicos = await _servicoService.getAll(apenasAtivos: true);
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao carregar serviços: $e',
          type: AppNoticeType.error,
        );
      }
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
      return;
    }

    if (!mounted) return;

    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final podeSalvar = cliente != null && servico != null;
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
                      'Novo agendamento',
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
                        final resultados = await _clienteService.search(query);
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
                          .toList(),
                      onChanged: (value) =>
                          setModalState(() => servico = value),
                    ),
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
                        label: const Text('Salvar agendamento'),
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
    if (cliente == null || servico == null) {
      UiFeedback.showSnack(
        context,
        'Selecione cliente e serviço para continuar.',
        type: AppNoticeType.error,
      );
      return;
    }

    try {
      await _agendaService.insert(
        Agendamento(
          clienteId: cliente!.id,
          clienteNome: cliente!.nome,
          servicoId: servico!.id,
          servicoNome: servico!.nome,
          dataHora: dataHora,
          observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Agendamento criado com sucesso.',
          type: AppNoticeType.success,
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao criar agendamento: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      buscaClienteCtrl.dispose();
      obsCtrl.dispose();
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoAgendamento,
        icon: const Icon(Icons.add),
        label: const Text('Novo agendamento'),
      ),
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
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () => _alterarStatus(agendamento),
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
                                  subtitle: Text(agendamento.servicoNome),
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
