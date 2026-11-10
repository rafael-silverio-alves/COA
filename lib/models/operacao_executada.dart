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
  double? rendimentoHaDia; // legado, mantido como fallback
  double? areaTotal;
  int? diasAntesPlantio;
  DateTime? dataPlantio;
  String? anoSafra;
  int? numeroPassadas;
  int? intervaloEntrePassadas;

  int? janelaInicioDias;
  int? janelaFimDias;

  // ===== NOVO: família da operação =====
  String? familiaId;
  String? familiaNome;
  double? rendimentoMedioTrator;
  int? numeroTratoresFamilia;

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
      dataInicioJanela: map['data_inicio_janela'] != null
          ? DateTime.tryParse(map['data_inicio_janela'])
          : null,
      dataFimJanela: map['data_fim_janela'] != null
          ? DateTime.tryParse(map['data_fim_janela'])
          : null,
      dataInicioPrimeira: map['data_inicio_primeira'] != null
          ? DateTime.tryParse(map['data_inicio_primeira'])
          : null,
      dataFimUltima: map['data_fim_ultima'] != null
          ? DateTime.tryParse(map['data_fim_ultima'])
          : null,
      areaExecutada: (map['area_executada'] as num?)?.toDouble(),
      status: map['status'] ?? 'planejada',
      passadasConcluidas: map['passadas_concluidas'] ?? 0,
      passadasNecessarias: map['passadas_necessarias'] ?? 1,
      janelaInicioDias: map['janela_inicio_dias'] as int?,
      janelaFimDias: map['janela_fim_dias'] as int?,
    );
  }

  // ============================================================
  // NOVO: helpers de família (com fallback)
  // ============================================================

  /// Rendimento por trator efetivo.
  /// Se a família tem rendimento válido, usa. Senão cai no legado.
  double get rendimentoEfetivoTrator {
    if (rendimentoMedioTrator != null && rendimentoMedioTrator! > 0) {
      return rendimentoMedioTrator!;
    }
    return rendimentoHaDia ?? 15.0;
  }

  /// Tratores efetivos. 0 significa que a operação NÃO usa trator.
  int get tratoresEfetivos => numeroTratoresFamilia ?? 0;

  /// Convenção: numero_tratores == 0 → operação sem trator.
  bool get usaTrator => tratoresEfetivos > 0;

  /// Chave de agrupamento na simulação.
  /// Operações sem família viram famílias isoladas (1 trator conceitual).
  String get familiaEfetivaId {
    if (familiaId != null && familiaId!.isNotEmpty) return familiaId!;
    return '__isolada_$operacaoPadraoId';
  }

  /// Área total considerando as passadas.
  double get areaTotalComPassadas {
    if (status == 'dispensada') return 0;
    return (areaTotal ?? 0) * (numeroPassadas ?? 1);
  }

  /// Duração pura em dias (tempo de máquina da operação sozinha).
  /// Usada:
  ///  - quando há filtro de pivô (1 trator por operação),
  ///  - para operações sem trator (duração fixa),
  ///  - informativamente na UI.
  int get duracaoPuraDias {
    if (status == 'dispensada') return 0;
    final area = areaTotalComPassadas;
    if (area <= 0) return 0;
    final rend = rendimentoEfetivoTrator;
    if (rend <= 0) return 1;
    return (area / rend).ceil().clamp(1, 999999);
  }

  // ============================================================
  // Datas e status (comportamento preservado)
  // ============================================================

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
    final dias = duracaoPuraDias;
    return inicio.add(Duration(days: dias > 7 ? dias : 7));
  }

  DateTime getDataInicioCalculada() {
    if (dataInicioPrimeira != null) return dataInicioPrimeira!;
    return getDataInicioJanelaCalculada();
  }

  int getDiasNecessarios() {
    if (status == 'dispensada') return 0;
    return duracaoPuraDias;
  }

  double getAreaTotalComPassadas() => areaTotalComPassadas;

  String getStatusText() {
    switch (status) {
      case 'concluida':
        return 'Concluído';
      case 'em_andamento':
        return 'Em andamento';
      case 'atrasada':
        return 'Atrasada';
      case 'dispensada':
        return 'Dispensada';
      default:
        return 'Planejada';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case 'concluida':
        return const Color(0xFF22C55E);
      case 'em_andamento':
        return const Color(0xFF3B82F6);
      case 'atrasada':
        return const Color(0xFFEF4444);
      case 'dispensada':
        return Colors.grey;
      default:
        return const Color(0xFFFACC15);
    }
  }

  bool get isRealmenteAtrasada {
    if (status == 'atrasada') return true;
    if (status == 'dispensada' || status == 'concluida') return false;
    final hoje = DateTime.now();
    final fimJanela = getDataFimJanelaCalculada();
    return hoje.isAfter(fimJanela);
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

  /// Atualização de status — só deve ser chamada por ação do usuário no app.
  /// A simulação do painel NÃO usa este método.
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