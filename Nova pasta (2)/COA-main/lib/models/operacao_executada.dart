import 'package:flutter/material.dart';

class OperacaoExecutada {
  final String id;
  final String safraId;
  final String operacaoPadraoId;
  
  DateTime? dataInicioJanela;
  DateTime? dataFimJanela;
  DateTime? dataInicioPrimeira;
  DateTime? dataFimUltima;
  
  final double? areaExecutada;
  String status;
  int passadasConcluidas;
  final int passadasNecessarias;
  
  String? pivoNome;
  String? operacaoNome;
  double? rendimentoHaDia;
  double? areaTotal;
  int? diasAntesPlantio;
  DateTime? dataPlantio;
  int? numeroPassadas;
  int? intervaloEntrePassadas;
  
  int? janelaInicioDias;
  int? janelaFimDias;

  OperacaoExecutada({
    required this.id,
    required this.safraId,
    required this.operacaoPadraoId,
    this.dataInicioJanela,
    this.dataFimJanela,
    this.dataInicioPrimeira,
    this.dataFimUltima,
    this.areaExecutada,
    required this.status,
    this.passadasConcluidas = 0,
    this.passadasNecessarias = 1,
    this.janelaInicioDias,
    this.janelaFimDias,
  });

  factory OperacaoExecutada.fromMap(Map<String, dynamic> map) {
    return OperacaoExecutada(
      id: map['id'] ?? '',
      safraId: map['safra_id'] ?? '',
      operacaoPadraoId: map['operacao_padrao_id'] ?? '',
      dataInicioJanela: map['data_inicio_janela'] != null ? DateTime.tryParse(map['data_inicio_janela']) : null,
      dataFimJanela: map['data_fim_janela'] != null ? DateTime.tryParse(map['data_fim_janela']) : null,
      dataInicioPrimeira: map['data_inicio_primeira'] != null ? DateTime.tryParse(map['data_inicio_primeira']) : null,
      dataFimUltima: map['data_fim_ultima'] != null ? DateTime.tryParse(map['data_fim_ultima']) : null,
      areaExecutada: (map['area_executada'] as num?)?.toDouble(),
      status: map['status'] ?? 'planejada',
      passadasConcluidas: map['passadas_concluidas'] ?? 0,
      passadasNecessarias: map['passadas_necessarias'] ?? 1,
      janelaInicioDias: map['janela_inicio_dias'] as int?,
      janelaFimDias: map['janela_fim_dias'] as int?,
    );
  }

  DateTime getDataInicioJanelaCalculada() {
    if (dataInicioJanela != null) return dataInicioJanela!;
    if (dataPlantio != null && janelaInicioDias != null) {
      return dataPlantio!.add(Duration(days: janelaInicioDias!));
    }
    if (dataPlantio != null && diasAntesPlantio != null) {
      return dataPlantio!.add(Duration(days: diasAntesPlantio!));
    }
    return DateTime.now();
  }
  
  DateTime getDataFimJanelaCalculada() {
    if (dataFimJanela != null) return dataFimJanela!;
    if (dataPlantio != null && janelaFimDias != null) {
      return dataPlantio!.add(Duration(days: janelaFimDias!));
    }
    final inicio = getDataInicioJanelaCalculada();
    final diasExecucao = getDiasNecessarios();
    return inicio.add(Duration(days: diasExecucao > 7 ? diasExecucao : 7));
  }

  DateTime getDataInicioCalculada() {
    if (dataInicioPrimeira != null) return dataInicioPrimeira!;
    return getDataInicioJanelaCalculada();
  }

  int getDiasNecessarios() {
    if (status == 'dispensada') return 0;
    final area = areaTotal ?? 0;
    final rendimento = rendimentoHaDia ?? 15.0;
    final passadas = numeroPassadas ?? 1;
    if (rendimento <= 0 || area <= 0) return 1;
    final areaTotalComPassadas = area * passadas;
    final dias = (areaTotalComPassadas / rendimento).ceil();
    return dias > 0 ? dias : 1;
  }

  double getAreaTotalComPassadas() {
    if (status == 'dispensada') return 0;
    if (areaTotal == null) return 0;
    return areaTotal! * (numeroPassadas ?? 1);
  }

  String getStatusText() {
    switch (status) {
      case 'concluida': return 'Concluído';
      case 'em_andamento': return 'Em andamento';
      case 'atrasada': return 'Atrasada';
      case 'dispensada': return 'Dispensada';
      default: return 'Planejada';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case 'concluida': return const Color(0xFF22C55E);
      case 'em_andamento': return const Color(0xFF3B82F6);
      case 'atrasada': return const Color(0xFFEF4444);
      case 'dispensada': return Colors.grey;
      default: return const Color(0xFFFACC15);
    }
  }

  bool get isRealmenteAtrasada {
    if (status == 'atrasada') return true;
    if (status == 'dispensada' || status == 'concluida') return false;
    final hoje = DateTime.now();
    final fimJanela = getDataFimJanelaCalculada();
    if (fimJanela != null && hoje.isAfter(fimJanela)) return true;
    return false;
  }

  String? get mensagemInconsistencia {
    if (isRealmenteAtrasada && status != 'atrasada') {
      final fimJanela = getDataFimJanelaCalculada();
      return '⚠️ Fora da janela (limite: ${fimJanela.day}/${fimJanela.month}/${fimJanela.year})';
    }
    return null;
  }

  Color get corDestaqueInconsistencia {
    if (isRealmenteAtrasada && status != 'atrasada') {
      return Colors.red.withOpacity(0.15);
    }
    return Colors.transparent;
  }

  bool get isAtrasada => status == 'atrasada';
  bool get isEmAndamento => status == 'em_andamento';
  bool get isConcluida => status == 'concluida';
  bool get isPlanejada => status == 'planejada';
  bool get isDispensada => status == 'dispensada';

  void atualizarStatus(String novoStatus) {
    status = novoStatus;
    if (novoStatus == 'em_andamento' && dataInicioPrimeira == null) {
      dataInicioPrimeira = DateTime.now();
    }
    if (novoStatus == 'concluida' && dataFimUltima == null) {
      dataFimUltima = DateTime.now();
    }
  }
}