import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../services/atendimento_service.dart';
import '../../services/cliente_service.dart';
import '../../services/financeiro_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/ui_helpers.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final AtendimentoService _atendimentoService = AtendimentoService();
  final ClienteService _clienteService = ClienteService();
  final FinanceiroService _financeiroService = FinanceiroService();

  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  bool _gerando = false;

  Future<void> _selecionarPeriodo() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
      locale: const Locale('pt', 'BR'),
    );

    if (range == null) return;
    setState(() {
      _inicio = range.start;
      _fim = range.end;
    });
  }

  Future<void> _exportarAtendimentosCsv() async {
    setState(() => _gerando = true);
    try {
      final atendimentos =
          await _atendimentoService.getPorPeriodo(_inicio, _fim);
      final rows = <List<dynamic>>[
        ['Data', 'Cliente', 'Total', 'Forma de pagamento', 'Observações'],
        ...atendimentos.map(
          (a) => [
            AppFormatters.dateTime(a.data),
            a.clienteNome,
            a.total.toStringAsFixed(2),
            a.formaPagamento,
            a.observacoes ?? '',
          ],
        ),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/atendimentos_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csv, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Relatório de atendimentos');

      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Relatório CSV gerado com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao gerar CSV: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _exportarClientesCsv() async {
    setState(() => _gerando = true);
    try {
      final clientes = await _clienteService.getAll();
      final rows = <List<dynamic>>[
        [
          'Nome',
          'Telefone',
          'Total gasto',
          'Atendimentos',
          'Última visita',
          'Pontos de fidelidade',
        ],
        ...clientes.map(
          (c) => [
            c.nome,
            c.telefone,
            c.totalGasto.toStringAsFixed(2),
            c.totalAtendimentos,
            c.ultimaVisita != null ? AppFormatters.date(c.ultimaVisita!) : '',
            c.pontosFidelidade,
          ],
        ),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/clientes_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csv, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Relatório de clientes');

      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Lista de clientes exportada.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao gerar CSV de clientes: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _exportarFinanceiroPdf() async {
    setState(() => _gerando = true);
    try {
      final resumo = await _financeiroService.getResumo(_inicio, _fim);
      final atendimentos =
          await _atendimentoService.getPorPeriodo(_inicio, _fim);
      final despesas = await _financeiroService.getDespesas(
        inicio: _inicio,
        fim: _fim,
      );

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Text(
              'Barbearia Pro - Relatório Financeiro',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Período: ${AppFormatters.date(_inicio)} a ${AppFormatters.date(_fim)}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Resumo',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfRow(
              'Faturamento bruto',
              AppFormatters.currency(
                  (resumo['faturamento'] as num?)?.toDouble() ?? 0),
            ),
            _pdfRow(
              'Despesas',
              AppFormatters.currency(
                  (resumo['despesas'] as num?)?.toDouble() ?? 0),
            ),
            _pdfRow(
              'Lucro líquido',
              AppFormatters.currency(
                  (resumo['lucro'] as num?)?.toDouble() ?? 0),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Atendimentos (${atendimentos.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Cliente', 'Total', 'Pagamento'],
              data: atendimentos
                  .take(60)
                  .map(
                    (a) => [
                      AppFormatters.date(a.data),
                      a.clienteNome,
                      AppFormatters.currency(a.total),
                      a.formaPagamento,
                    ],
                  )
                  .toList(growable: false),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE94560)),
            ),
            if (despesas.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Despesas (${despesas.length})',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Data', 'Descrição', 'Categoria', 'Valor'],
                data: despesas
                    .map(
                      (d) => [
                        AppFormatters.date(d.data),
                        d.descricao,
                        d.categoria,
                        AppFormatters.currency(d.valor),
                      ],
                    )
                    .toList(growable: false),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Text(
              'Gerado em ${AppFormatters.dateTime(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF999999),
              ),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Relatório financeiro',
      );

      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Relatório financeiro gerado com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao gerar PDF: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _exportarExcel() async {
    setState(() => _gerando = true);
    try {
      final atendimentos =
          await _atendimentoService.getPorPeriodo(_inicio, _fim);

      final excel = Excel.createExcel();
      final sheet = excel['Atendimentos'];
      sheet.appendRow([
        TextCellValue('Data'),
        TextCellValue('Cliente'),
        TextCellValue('Total'),
        TextCellValue('Forma de pagamento'),
      ]);

      for (final a in atendimentos) {
        sheet.appendRow([
          TextCellValue(AppFormatters.dateTime(a.data)),
          TextCellValue(a.clienteNome),
          DoubleCellValue(a.total),
          TextCellValue(a.formaPagamento),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Falha ao gerar arquivo Excel.');

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/atendimentos_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: 'Relatório em Excel',
      );

      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Planilha Excel gerada com sucesso.',
          type: AppNoticeType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.showSnack(
          context,
          'Falha ao gerar Excel: $e',
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedItem: AppDrawer.relatorios),
      appBar: AppBar(title: const Text('Relatórios')),
      body: AppPageContainer(
        maxWidth: 860,
        child: ListView(
          children: [
            if (_gerando)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Período do relatório',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PeriodoInfo(
                            label: 'Início',
                            value: AppFormatters.date(_inicio),
                            alignEnd: false,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward),
                        ),
                        Expanded(
                          child: _PeriodoInfo(
                            label: 'Fim',
                            value: AppFormatters.date(_fim),
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _gerando ? null : _selecionarPeriodo,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Selecionar período'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Exportações',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _RelatorioActionCard(
              icon: Icons.picture_as_pdf,
              title: 'Relatório financeiro (PDF)',
              subtitle: 'Resumo financeiro, atendimentos e despesas',
              color: AppTheme.errorColor,
              onTap: _gerando ? null : _exportarFinanceiroPdf,
            ),
            const SizedBox(height: 10),
            _RelatorioActionCard(
              icon: Icons.table_chart,
              title: 'Atendimentos (CSV)',
              subtitle: 'Lista detalhada de atendimentos no período',
              color: AppTheme.successColor,
              onTap: _gerando ? null : _exportarAtendimentosCsv,
            ),
            const SizedBox(height: 10),
            _RelatorioActionCard(
              icon: Icons.people,
              title: 'Clientes (CSV)',
              subtitle: 'Base de clientes com histórico e fidelidade',
              color: AppTheme.infoColor,
              onTap: _gerando ? null : _exportarClientesCsv,
            ),
            const SizedBox(height: 10),
            _RelatorioActionCard(
              icon: Icons.grid_on,
              title: 'Atendimentos (Excel)',
              subtitle: 'Planilha .xlsx para análises externas',
              color: Colors.green,
              onTap: _gerando ? null : _exportarExcel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodoInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _PeriodoInfo({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RelatorioActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _RelatorioActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.download),
        onTap: onTap,
      ),
    );
  }
}
