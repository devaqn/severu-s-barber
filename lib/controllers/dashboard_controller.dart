import 'package:flutter/foundation.dart';

import '../services/dashboard_service.dart';
import 'controller_mixin.dart';

class DashboardController extends ChangeNotifier with ControllerMixin {
  DashboardController({DashboardService? dashboardService})
      : _service = dashboardService ?? DashboardService();

  final DashboardService _service;

  Map<String, dynamic>? dados;
  DateTime? ultimaAtualizacao;

  bool get hasDados => dados != null;

  Future<void> carregar({bool forceRefresh = false}) async {
    if (isLoading) return;
    if (!forceRefresh && hasDados) return;
    await _carregarDados();
  }

  Future<void> recarregar() async {
    if (isLoading) return;
    await _carregarDados();
  }

  Future<void> _carregarDados() => runSilent(() async {
        dados = await _service.getDadosDashboard();
        ultimaAtualizacao = DateTime.now();
      });
}
