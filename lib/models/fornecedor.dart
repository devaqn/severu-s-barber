// ============================================================
// fornecedor.dart
// Model que representa um fornecedor de produtos da barbearia.
// ============================================================

class Fornecedor {
  final int? id;
  final String nome;
  final String? telefone;
  final String? email;
  final String? observacoes;
  final DateTime createdAt;

  const Fornecedor({
    this.id,
    required this.nome,
    this.telefone,
    this.email,
    this.observacoes,
    required this.createdAt,
  });

  factory Fornecedor.fromMap(Map<String, dynamic> map) {
    return Fornecedor(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      telefone: map['telefone'] as String?,
      email: map['email'] as String?,
      observacoes: map['observacoes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'observacoes': observacoes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Fornecedor copyWith({
    int? id,
    String? nome,
    String? telefone,
    String? email,
    String? observacoes,
  }) {
    return Fornecedor(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      observacoes: observacoes ?? this.observacoes,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Fornecedor) return false;
    if (id != null && other.id != null) return other.id == id;
    return other.nome == nome &&
        other.telefone == telefone &&
        other.email == email;
  }

  @override
  int get hashCode => id?.hashCode ?? Object.hash(nome, telefone, email);

  @override
  String toString() => 'Fornecedor(id: $id, nome: $nome)';
}
