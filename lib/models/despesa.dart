// ============================================================
// despesa.dart
// Model que representa uma despesa da barbearia.
// Exemplos: aluguel, energia, compra de produtos, etc.
// ============================================================

class Despesa {
  final int? id;
  final String descricao;
  final String categoria;
  final double valor;
  final DateTime data;
  final String? observacoes;

  const Despesa({
    this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    this.observacoes,
  });

  factory Despesa.fromMap(Map<String, dynamic> map) {
    return Despesa(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      categoria: map['categoria'] as String,
      valor: (map['valor'] as num).toDouble(),
      data: DateTime.parse(map['data'] as String),
      observacoes: map['observacoes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'descricao': descricao,
      'categoria': categoria,
      'valor': valor,
      'data': data.toIso8601String(),
      'observacoes': observacoes,
    };
  }

  Despesa copyWith({
    int? id,
    String? descricao,
    String? categoria,
    double? valor,
    DateTime? data,
    String? observacoes,
  }) {
    return Despesa(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      observacoes: observacoes ?? this.observacoes,
    );
  }

  @override
  String toString() => 'Despesa(id: $id, descricao: $descricao, valor: $valor)';
}
