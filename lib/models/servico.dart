// ============================================================
// servico.dart
// Model que representa um serviço oferecido pela barbearia.
// Exemplos: Corte, Barba, Sobrancelha, etc.
// Inclui comissão configurável por barbeiro.
// ============================================================

class Servico {
  final int? id;
  final String nome;
  final double preco;
  /// Duração média do serviço em minutos
  final int duracaoMinutos;
  /// Percentual de comissão do barbeiro (0.0 a 1.0)
  final double comissaoPercentual;
  final bool ativo;

  const Servico({
    this.id,
    required this.nome,
    required this.preco,
    this.duracaoMinutos = 30,
    this.comissaoPercentual = 0.50,
    this.ativo = true,
  });

  factory Servico.fromMap(Map<String, dynamic> map) {
    return Servico(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      preco: (map['preco'] as num).toDouble(),
      duracaoMinutos: (map['duracao_minutos'] as int?) ?? 30,
      comissaoPercentual: (map['comissao_percentual'] as num?)?.toDouble() ?? 0.50,
      ativo: (map['ativo'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'preco': preco,
      'duracao_minutos': duracaoMinutos,
      'comissao_percentual': comissaoPercentual,
      'ativo': ativo ? 1 : 0,
    };
  }

  Servico copyWith({
    int? id,
    String? nome,
    double? preco,
    int? duracaoMinutos,
    double? comissaoPercentual,
    bool? ativo,
  }) {
    return Servico(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      preco: preco ?? this.preco,
      duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
      comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
      ativo: ativo ?? this.ativo,
    );
  }

  @override
  String toString() => 'Servico(id: $id, nome: $nome, preco: $preco)';
}
