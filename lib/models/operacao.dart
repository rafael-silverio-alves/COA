class Operacao {
  final String id;
  final String pivo;
  final String operacao;
  final String cultura;
  final double area;
  final DateTime dataPlantio;
  final DateTime janelaInicio;
  final DateTime janelaFim;
  bool finalizada;
  bool emAndamento;

  Operacao({
    required this.id,
    required this.pivo,
    required this.operacao,
    required this.cultura,
    required this.area,
    required this.dataPlantio,
    required this.janelaInicio,
    required this.janelaFim,
    this.finalizada = false,
    this.emAndamento = false,
  });
}