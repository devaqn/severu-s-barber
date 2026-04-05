// ============================================================
// usuario.dart
// Modelo de usuario (Admin/Barbeiro) com dados de comissao.
// ============================================================

class Usuario {
  static const Object _naoInformado = Object();

  final String id;
  final String nome;
  final String email;
  final String? telefone;
  final String? photoUrl;
  final String? barbeariaId;

  /// 'admin' ou 'barbeiro'
  final String role;
  final bool ativo;

  /// Percentual de comissao em escala 0..100.
  final double comissaoPercentual;
  final bool firstLogin;
  final DateTime createdAt;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone,
    this.photoUrl,
    this.barbeariaId,
    required this.role,
    this.ativo = true,
    this.comissaoPercentual = 50.0,
    this.firstLogin = false,
    required this.createdAt,
  });

  /// Valor em escala decimal (0..1), com compatibilidade retroativa.
  double get comissaoDecimal {
    final base =
        comissaoPercentual > 1 ? comissaoPercentual / 100 : comissaoPercentual;
    return base.clamp(0.0, 1.0).toDouble();
  }

  bool get isAdmin => role == 'admin';
  bool get isBarbeiro => role == 'barbeiro';

  factory Usuario.fromMap(Map<String, dynamic> map) {
    final ativoRaw = map['ativo'];
    final firstLoginRaw = map['first_login'];

    return Usuario(
      id: map['id'] as String,
      nome: map['nome'] as String,
      email: map['email'] as String,
      telefone: map['telefone'] as String?,
      photoUrl: map['photo_url'] as String?,
      barbeariaId: map['barbearia_id'] as String?,
      role: (map['role'] as String?) ?? 'barbeiro',
      ativo: ativoRaw is bool ? ativoRaw : ((ativoRaw as int?) ?? 1) == 1,
      comissaoPercentual:
          (map['comissao_percentual'] as num?)?.toDouble() ?? 50.0,
      firstLogin: firstLoginRaw is bool
          ? firstLoginRaw
          : ((firstLoginRaw as int?) ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'photo_url': photoUrl,
      'barbearia_id': barbeariaId,
      'role': role,
      'ativo': ativo ? 1 : 0,
      'comissao_percentual': comissaoPercentual,
      'first_login': firstLogin ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'photo_url': photoUrl,
      'barbearia_id': barbeariaId,
      'role': role,
      'ativo': ativo,
      'comissao_percentual': comissaoPercentual,
      'first_login': firstLogin,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Usuario.fromFirestore(Map<String, dynamic> data) {
    return Usuario(
      id: (data['id'] ?? '') as String,
      nome: (data['nome'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      telefone: data['telefone'] as String?,
      photoUrl: data['photo_url'] as String?,
      barbeariaId: data['barbearia_id'] as String?,
      role: (data['role'] as String?) ?? 'barbeiro',
      ativo: (data['ativo'] as bool?) ?? true,
      comissaoPercentual:
          (data['comissao_percentual'] as num?)?.toDouble() ?? 50.0,
      firstLogin: (data['first_login'] as bool?) ?? false,
      createdAt: data['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(data['created_at'] as String),
    );
  }

  Usuario copyWith({
    String? nome,
    String? email,
    Object? telefone = _naoInformado,
    Object? photoUrl = _naoInformado,
    Object? barbeariaId = _naoInformado,
    String? role,
    bool? ativo,
    double? comissaoPercentual,
    bool? firstLogin,
  }) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: identical(telefone, _naoInformado)
          ? this.telefone
          : telefone as String?,
      photoUrl: identical(photoUrl, _naoInformado)
          ? this.photoUrl
          : photoUrl as String?,
      barbeariaId: identical(barbeariaId, _naoInformado)
          ? this.barbeariaId
          : barbeariaId as String?,
      role: role ?? this.role,
      ativo: ativo ?? this.ativo,
      comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
      firstLogin: firstLogin ?? this.firstLogin,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'Usuario(id: $id, nome: $nome, role: $role)';
}
