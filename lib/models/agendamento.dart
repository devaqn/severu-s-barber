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
  final String? barbeiroId;
  final String? barbeiroNome;

  /// Data e hora do agendamento
  final DateTime dataHora;
  final String status;
  final bool faturamentoRegistrado;
  final String? observacoes;
  final DateTime createdAt;

  const Agendamento({
    this.id,
    this.clienteId,
    required this.clienteNome,
    this.servicoId,
    required this.servicoNome,
    this.barbeiroId,
    this.barbeiroNome,
    required this.dataHora,
    this.status = 'Pendente',
    this.faturamentoRegistrado = false,
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
      barbeiroId: map['barbeiro_id'] as String?,
      barbeiroNome: map['barbeiro_nome'] as String?,
      dataHora: DateTime.parse(map['data_hora'] as String),
      status: (map['status'] as String?) ?? 'Pendente',
      faturamentoRegistrado:
          ((map['faturamento_registrado'] as num?)?.toInt() ?? 0) == 1,
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
      'barbeiro_id': barbeiroId,
      'barbeiro_nome': barbeiroNome,
      'data_hora': dataHora.toIso8601String(),
      'status': status,
      'faturamento_registrado': faturamentoRegistrado ? 1 : 0,
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
    String? barbeiroId,
    String? barbeiroNome,
    DateTime? dataHora,
    String? status,
    bool? faturamentoRegistrado,
    String? observacoes,
  }) {
    return Agendamento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      servicoId: servicoId ?? this.servicoId,
      servicoNome: servicoNome ?? this.servicoNome,
      barbeiroId: barbeiroId ?? this.barbeiroId,
      barbeiroNome: barbeiroNome ?? this.barbeiroNome,
      dataHora: dataHora ?? this.dataHora,
      status: status ?? this.status,
      faturamentoRegistrado:
          faturamentoRegistrado ?? this.faturamentoRegistrado,
      observacoes: observacoes ?? this.observacoes,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Agendamento) return false;
    if (id != null && other.id != null) return other.id == id;
    return other.clienteId == clienteId &&
        other.clienteNome == clienteNome &&
        other.servicoId == servicoId &&
        other.servicoNome == servicoNome &&
        other.barbeiroId == barbeiroId &&
        other.dataHora == dataHora;
  }

  @override
  int get hashCode =>
      id?.hashCode ??
      Object.hash(
        clienteId,
        clienteNome,
        servicoId,
        servicoNome,
        barbeiroId,
        dataHora,
      );

  @override
  String toString() =>
      'Agendamento(id: $id, cliente: $clienteNome, data: $dataHora)';
}
