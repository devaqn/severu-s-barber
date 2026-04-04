// ============================================================
// usuario.dart
// Model que representa um usuário do sistema (Admin ou Barbeiro).
// Usado para controle de acesso e comissões.
// ============================================================

class Usuario {
  final String id;
  final String nome;
  final String email;
  /// 'admin' ou 'barbeiro'
  final String role;
  final bool ativo;
  /// Percentual padrão de comissão do barbeiro (0.0 a 1.0)
  final double comissaoPercentual;
  final DateTime createdAt;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
    this.ativo = true,
    this.comissaoPercentual = 0.50,
    required this.createdAt,
  });

  /// Verifica se o usuário é administrador
  bool get isAdmin => role == 'admin';

  /// Verifica se o usuário é barbeiro
  bool get isBarbeiro => role == 'barbeiro';

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as String,
      nome: map['nome'] as String,
      email: map['email'] as String,
      role: (map['role'] as String?) ?? 'barbeiro',
      ativo: (map['ativo'] as int?) == 1,
      comissaoPercentual: (map['comissao_percentual'] as num?)?.toDouble() ?? 0.50,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Converte para Map para persistência local (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'role': role,
      'ativo': ativo ? 1 : 0,
      'comissao_percentual': comissaoPercentual,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converte para Map para Firestore (sem ativo como int)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'role': role,
      'ativo': ativo,
      'comissao_percentual': comissaoPercentual,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Usuario.fromFirestore(Map<String, dynamic> data) {
    return Usuario(
      id: data['id'] as String,
      nome: data['nome'] as String,
      email: data['email'] as String,
      role: (data['role'] as String?) ?? 'barbeiro',
      ativo: (data['ativo'] as bool?) ?? true,
      comissaoPercentual: (data['comissao_percentual'] as num?)?.toDouble() ?? 0.50,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Usuario copyWith({
    String? nome,
    String? email,
    String? role,
    bool? ativo,
    double? comissaoPercentual,
  }) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      role: role ?? this.role,
      ativo: ativo ?? this.ativo,
      comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'Usuario(id: $id, nome: $nome, role: $role)';
}
