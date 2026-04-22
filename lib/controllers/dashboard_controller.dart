import 'package:flutter/foundation.dart';

import '../services/dashboard_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({DashboardService? dashboardService})
      : _service = dashboardService ?? DashboardService();

  final DashboardService _service;

  bool isLoading = false;
  String? errorMsg;
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

  Future<void> _carregarDados() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();

    try {
      dados = await _service.getDadosDashboard();
      ultimaAtualizacao = DateTime.now();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
