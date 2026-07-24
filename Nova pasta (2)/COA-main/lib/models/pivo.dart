class Pivo {
  final String id;
  final String nome;
  final String? localizacao;
  final double areaTotal;
  final DateTime createdAt;

  Pivo({
    required this.id,
    required this.nome,
    this.localizacao,
    required this.areaTotal,
    required this.createdAt,
  });

  factory Pivo.fromMap(Map<String, dynamic> map) {
    return Pivo(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      localizacao: map['localizacao'],
      areaTotal: (map['area_total'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'localizacao': localizacao,
      'area_total': areaTotal,
      'created_at': createdAt.toIso8601String(),
    };
  }
}