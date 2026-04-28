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
  });

  factory Safra.fromMap(Map<String, dynamic> map) {
    return Safra(
      id: map['id'] ?? '',
      pivoId: map['pivo_id'] ?? '',
      culturaId: map['cultura_id'] ?? '',
      dataPlantio: DateTime.parse(map['data_plantio']),
      anoSafra: map['ano_safra'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}