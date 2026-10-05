class Safra {
  final String id;
  final String pivoId;
  final String culturaId;
  final DateTime dataPlantio;
  final String? anoSafra;
  final DateTime createdAt;

  String? pivoNome;
  String? culturaNome;

  Safra({
    required this.id,
    required this.pivoId,
    required this.culturaId,
    required this.dataPlantio,
    this.anoSafra,
    required this.createdAt,
    this.pivoNome,
    this.culturaNome,
  });

  factory Safra.fromMap(Map<String, dynamic> map) {
    // Suporta tanto o retorno simples quanto o join com pivos(*)
    final pivoJoin = map['pivos'] as Map<String, dynamic>?;
    final culturaJoin = map['culturas'] as Map<String, dynamic>?;

    return Safra(
      id: map['id'] ?? '',
      pivoId: map['pivo_id'] ?? '',
      culturaId: map['cultura_id'] ?? '',
      dataPlantio: DateTime.parse(map['data_plantio']),
      anoSafra: map['ano_safra'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      pivoNome: pivoJoin?['nome'] as String?,
      culturaNome: culturaJoin?['nome'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pivo_id': pivoId,
      'cultura_id': culturaId,
      'data_plantio': dataPlantio.toIso8601String().split('T').first,
      'ano_safra': anoSafra,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Safra copyWith({
    String? id,
    String? pivoId,
    String? culturaId,
    DateTime? dataPlantio,
    String? anoSafra,
    DateTime? createdAt,
    String? pivoNome,
    String? culturaNome,
  }) {
    return Safra(
      id: id ?? this.id,
      pivoId: pivoId ?? this.pivoId,
      culturaId: culturaId ?? this.culturaId,
      dataPlantio: dataPlantio ?? this.dataPlantio,
      anoSafra: anoSafra ?? this.anoSafra,
      createdAt: createdAt ?? this.createdAt,
      pivoNome: pivoNome ?? this.pivoNome,
      culturaNome: culturaNome ?? this.culturaNome,
    );
  }
}