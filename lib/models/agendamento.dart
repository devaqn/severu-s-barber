// ============================================================
// agendamento.dart
// Model que representa um agendamento na agenda da barbearia.
// ============================================================

class Agendamento {
  final int? id;
  final int? clienteId;
  final String clienteNome;
  final int? servicoId;
  final String servicoNome;
  /// Data e hora do agendamento
  final DateTime dataHora;
  final String status;
  final String? observacoes;
  final DateTime createdAt;

  const Agendamento({
    this.id,
    this.clienteId,
    required this.clienteNome,
    this.servicoId,
    required this.servicoNome,
    required this.dataHora,
    this.status = 'Pendente',
    this.observacoes,
    required this.createdAt,
  });

  factory Agendamento.fromMap(Map<String, dynamic> map) {
    return Agendamento(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int?,
      clienteNome: map['cliente_nome'] as String,
      servicoId: map['servico_id'] as int?,
      servicoNome: map['servico_nome'] as String,
      dataHora: DateTime.parse(map['data_hora'] as String),
      status: (map['status'] as String?) ?? 'Pendente',
      observacoes: map['observacoes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'cliente_nome': clienteNome,
      'servico_id': servicoId,
      'servico_nome': servicoNome,
      'data_hora': dataHora.toIso8601String(),
      'status': status,
      'observacoes': observacoes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Agendamento copyWith({
    int? id,
    int? clienteId,
    String? clienteNome,
    int? servicoId,
    String? servicoNome,
    DateTime? dataHora,
    String? status,
    String? observacoes,
  }) {
    return Agendamento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      servicoId: servicoId ?? this.servicoId,
      servicoNome: servicoNome ?? this.servicoNome,
      dataHora: dataHora ?? this.dataHora,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'Agendamento(id: $id, cliente: $clienteNome, data: $dataHora)';
}
