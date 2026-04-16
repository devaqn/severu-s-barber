// ============================================================
// cliente.dart
// Model que representa um cliente da barbearia.
// ============================================================

class Cliente {
  static const Object _noValue = Object();

  final int? id;
  final String nome;
  final String telefone;
  final String? observacoes;
  final DateTime? dataNascimento;
  /// Total acumulado gasto na barbearia (em reais)
  final double totalGasto;
  /// Data do ultimo atendimento
  final DateTime? ultimaVisita;
  /// Pontos do programa de fidelidade
  final int pontosFidelidade;
  /// Quantidade total de atendimentos realizados
  final int totalAtendimentos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cliente({
    this.id,
    required this.nome,
    required this.telefone,
    this.observacoes,
    this.dataNascimento,
    this.totalGasto = 0.0,
    this.ultimaVisita,
    this.pontosFidelidade = 0,
    this.totalAtendimentos = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    final dataNascimentoRaw = map['data_nascimento'] as String?;
    return Cliente(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      telefone: map['telefone'] as String,
      observacoes: map['observacoes'] as String?,
      dataNascimento: dataNascimentoRaw == null || dataNascimentoRaw.isEmpty
          ? null
          : DateTime.tryParse(dataNascimentoRaw),
      totalGasto: (map['total_gasto'] as num?)?.toDouble() ?? 0.0,
      ultimaVisita: map['ultima_visita'] != null
          ? DateTime.parse(map['ultima_visita'] as String)
          : null,
      pontosFidelidade: (map['pontos_fidelidade'] as int?) ?? 0,
      totalAtendimentos: (map['total_atendimentos'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'telefone': telefone,
      'observacoes': observacoes,
      'data_nascimento': dataNascimento == null
          ? null
          : DateTime(
              dataNascimento!.year,
              dataNascimento!.month,
              dataNascimento!.day,
            ).toIso8601String().split('T').first,
      'total_gasto': totalGasto,
      'ultima_visita': ultimaVisita?.toIso8601String(),
      'pontos_fidelidade': pontosFidelidade,
      'total_atendimentos': totalAtendimentos,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Cliente copyWith({
    int? id,
    String? nome,
    String? telefone,
    String? observacoes,
    Object? dataNascimento = _noValue,
    double? totalGasto,
    DateTime? ultimaVisita,
    int? pontosFidelidade,
    int? totalAtendimentos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      observacoes: observacoes ?? this.observacoes,
      dataNascimento: identical(dataNascimento, _noValue)
          ? this.dataNascimento
          : dataNascimento as DateTime?,
      totalGasto: totalGasto ?? this.totalGasto,
      ultimaVisita: ultimaVisita ?? this.ultimaVisita,
      pontosFidelidade: pontosFidelidade ?? this.pontosFidelidade,
      totalAtendimentos: totalAtendimentos ?? this.totalAtendimentos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get temCorteGratis => pontosFidelidade >= 10;
  int get cortesParaBrinde => 10 - (pontosFidelidade % 10);

  @override
  String toString() => 'Cliente(id: $id, nome: $nome, telefone: $telefone)';
}
