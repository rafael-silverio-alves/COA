class OperacaoPadrao {
  final String id;
  final String nome;
  final int diasAntesPlantio;
  final double rendimentoHaDia;
  final String? culturaId;

  OperacaoPadrao({
    required this.id,
    required this.nome,
    required this.diasAntesPlantio,
    required this.rendimentoHaDia,
    this.culturaId,
  });

  factory OperacaoPadrao.fromMap(Map<String, dynamic> map) {
    return OperacaoPadrao(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      diasAntesPlantio: map['dias_antes_plantio'] ?? 0,
      rendimentoHaDia: (map['rendimento_ha_dia'] ?? 0).toDouble(),
      culturaId: map['cultura_id'],
    );
  }

  DateTime calcularDataInicio(DateTime dataPlantio) {
    return dataPlantio.add(Duration(days: diasAntesPlantio));
  }

  int calcularDiasNecessarios(double area) {
    return (area / rendimentoHaDia).ceil();
  }

  DateTime calcularDataTermino(DateTime dataInicio, double area) {
    final dias = calcularDiasNecessarios(area);
    return dataInicio.add(Duration(days: dias));
  }
}