import 'package:flutter/foundation.dart';

import '../models/agendamento.dart';
import '../services/agenda_service.dart';

class AgendaController extends ChangeNotifier {
  AgendaController({AgendaService? agendaService})
      : _service = agendaService ?? AgendaService();

  final AgendaService _service;

  bool isLoading = false;
  String? errorMsg;
  List<Agendamento> agendamentos = [];

  Future<void> carregar() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      agendamentos = await _service.getAll();
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Agendamento>> getAll() async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      final dados = await _service.getAll();
      agendamentos = List<Agendamento>.from(dados);
      return dados;
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      return const <Agendamento>[];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> insert(Agendamento agendamento) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await _service.insert(agendamento);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> update(Agendamento agendamento) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.update(agendamento);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(int id, String status) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.updateStatus(id, status);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> delete(int id) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await _service.delete(id);
    } catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
