import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_service.dart';
import '../models/operacao_executada.dart';
import '../services/pdf_service.dart';
import '../providers/auth_provider.dart';

class PainelScreen extends StatefulWidget {
  final AppService service;

  const PainelScreen({super.key, required this.service});

  @override
  State<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends State<PainelScreen> {
  String _filtroPivo = 'Todos';
  String _filtroOperacao = 'Todas';
  String? _filtroAnoSafra;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  Map<String, bool> _expandedPivos = {};
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  final Map<String, bool> _secoesExpandidas = {
    'insights': false,
    'grafico': false,
    'resumoPlantios': false,
    'ops_Concluídas': false,
    'ops_Em andamento': false,
    'ops_Planejadas': false,
    'ops_Atrasadas': false,
    'ops_Dispensadas': false,
  };

  List<OperacaoExecutada>? _operacoesFiltradasCache;
  String? _lastFiltroPivo;
  String? _lastFiltroOperacao;
  String? _lastFiltroAnoSafra;
  DateTime? _lastDataInicio;
  DateTime? _lastDataFim;

  Map<String, int>? _resumoCache;
  Map<String, dynamic>? _insightsCache;
  Map<String, dynamic>? _progressoPivosCache;

  List<String>? _anosSafraDisponiveisCache;
  DateTime? _lastAnoDataInicio;
  DateTime? _lastAnoDataFim;

  final Map<String, Color> _cores = {
    'Concluído': const Color(0xFF22C55E),
    'Em andamento': const Color(0xFF3B82F6),
    'Planejada': const Color(0xFFFACC15),
    'Atrasada': const Color(0xFFEF4444),
    'Dispensada': Colors.grey,
  };

  static const Color _neutroFundo = Color(0xFFF8F9FA);
  static const Color _neutroBorda = Color(0xFFE5E7EB);
  static const Color _neutroTexto = Color(0xFF374151);
  static const Color _neutroTextoSuave = Color(0xFF6B7280);
  static const Color _neutroIcone = Color(0xFF9CA3AF);
  static const Color _destaque = Color(0xFF2563EB);
  static const Color _destaqueFundo = Color(0xFFEFF6FF);
  static const Color _destaqueBorda = Color(0xFFBFDBFE);

  void _invalidarCaches() {
    _operacoesFiltradasCache = null;
    _resumoCache = null;
    _insightsCache = null;
    _progressoPivosCache = null;
  }

  // ============================================================
  // ANOS SAFRA DISPONÍVEIS (respeitando o filtro de data)
  // ============================================================
  List<String> get _anosSafraDisponiveis {
    if (_anosSafraDisponiveisCache != null &&
        _dataInicio == _lastAnoDataInicio &&
        _dataFim == _lastAnoDataFim) {
      return _anosSafraDisponiveisCache!;
    }

    _lastAnoDataInicio = _dataInicio;
    _lastAnoDataFim = _dataFim;

    final Set<String> anos = {};

    for (final op in widget.service.operacoes) {
      final plantio = op.dataPlantio;
      if (plantio == null) continue;

      if (_dataInicio != null && plantio.isBefore(_dataInicio!)) continue;
      if (_dataFim != null && plantio.isAfter(_dataFim!)) continue;

      final ano = op.anoSafra ?? '${plantio.year}/${plantio.year + 1}';
      anos.add(ano);
    }

    final lista = anos.toList();
    lista.sort((a, b) => b.compareTo(a));

    _anosSafraDisponiveisCache = lista;
    return lista;
  }

  bool get _anoSafraSelecionadoValido {
    if (_filtroAnoSafra == null) return true;
    return _anosSafraDisponiveis.contains(_filtroAnoSafra);
  }

  List<OperacaoExecutada> get _operacoesFiltradas {
    if (_operacoesFiltradasCache != null &&
        _filtroPivo == _lastFiltroPivo &&
        _filtroOperacao == _lastFiltroOperacao &&
        _filtroAnoSafra == _lastFiltroAnoSafra &&
        _dataInicio == _lastDataInicio &&
        _dataFim == _lastDataFim) {
      return _operacoesFiltradasCache!;
    }

    _lastFiltroPivo = _filtroPivo;
    _lastFiltroOperacao = _filtroOperacao;
    _lastFiltroAnoSafra = _filtroAnoSafra;
    _lastDataInicio = _dataInicio;
    _lastDataFim = _dataFim;

    _operacoesFiltradasCache = _calcularOperacoesFiltradas();
    _resumoCache = null;
    _insightsCache = null;
    _progressoPivosCache = null;
    return _operacoesFiltradasCache!;
  }

  bool get _temFiltroData => _dataInicio != null || _dataFim != null;

  bool get _temFiltroAtivo =>
      _filtroPivo != 'Todos' ||
      _filtroOperacao != 'Todas' ||
      _filtroAnoSafra != null ||
      _temFiltroData;

  List<OperacaoExecutada> _calcularOperacoesFiltradas() {
    if (_filtroAnoSafra != null && !_anoSafraSelecionadoValido) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _filtroAnoSafra = null);
        }
      });
    }

    final anoEfetivo =
        (_filtroAnoSafra != null && _anoSafraSelecionadoValido)
            ? _filtroAnoSafra
            : null;

    var operacoes = widget.service.operacoes.where((op) {
      if (_filtroPivo != 'Todos' && op.pivoNome != _filtroPivo) return false;
      if (_filtroOperacao != 'Todas' && op.operacaoNome != _filtroOperacao) {
        return false;
      }

      if (anoEfetivo != null) {
        final ano = op.anoSafra ??
            (op.dataPlantio != null
                ? '${op.dataPlantio!.year}/${op.dataPlantio!.year + 1}'
                : null);
        if (ano != anoEfetivo) return false;
      } else if (_temFiltroData) {
        final plantio = op.dataPlantio;
        if (plantio == null) return false;
        if (_dataInicio != null && plantio.isBefore(_dataInicio!)) {
          return false;
        }
        if (_dataFim != null && plantio.isAfter(_dataFim!)) return false;
      }

      return true;
    }).toList();

    operacoes.sort((a, b) {
      DateTime? dataA;
      DateTime? dataB;

      if (a.status == 'concluida') {
        dataA = a.dataFimUltima;
      } else {
        dataA = a.getDataInicioJanelaCalculada();
      }

      if (b.status == 'concluida') {
        dataB = b.dataFimUltima;
      } else {
        dataB = b.getDataInicioJanelaCalculada();
      }

      final dateA = dataA ?? DateTime(3000);
      final dateB = dataB ?? DateTime(3000);
      return dateA.compareTo(dateB);
    });

    return operacoes;
  }

  Map<String, int> get _resumo {
    if (_resumoCache != null) return _resumoCache!;

    final resumo = {
      'Concluído': 0,
      'Em andamento': 0,
      'Planejada': 0,
      'Atrasada': 0,
      'Dispensada': 0,
    };
    for (var op in _operacoesFiltradas) {
      final status = op.getStatusText();
      resumo[status] = (resumo[status] ?? 0) + 1;
    }
    _resumoCache = resumo;
    return resumo;
  }

  Map<String, dynamic> get _insights {
    if (_insightsCache != null) return _insightsCache!;

    double totalRealizado = 0;
    double totalAExecutar = 0;
    int operacoesConcluidas = 0;
    int operacoesPendentes = 0;

    for (var op in _operacoesFiltradas) {
      if (op.status == 'dispensada') continue;
      final area = (op.areaTotal ?? 0) * (op.numeroPassadas ?? 1);

      if (op.status == 'concluida') {
        totalRealizado += area;
        operacoesConcluidas++;
      } else {
        totalAExecutar += area;
        operacoesPendentes++;
      }
    }

    final Map<String, double> rendimentoPorOperacao = {};
    for (var op in _operacoesFiltradas) {
      if (op.status == 'dispensada' || op.status == 'concluida') continue;
      final rendimento = op.rendimentoHaDia ?? 0;
      if (rendimento <= 0) continue;
      final nomeOp = op.operacaoNome ?? 'Sem nome';
      rendimentoPorOperacao.putIfAbsent(nomeOp, () => rendimento);
    }

    double capacidadeTotal;
    if (_filtroPivo != 'Todos') {
      capacidadeTotal = rendimentoPorOperacao.isEmpty
          ? 0
          : rendimentoPorOperacao.values.reduce(min);
    } else {
      capacidadeTotal =
          rendimentoPorOperacao.values.fold<double>(0, (a, b) => a + b);
    }

    final Map<String, List<OperacaoExecutada>> opsPorPivo = {};
    for (var op in _operacoesFiltradas) {
      if (op.status == 'dispensada' || op.status == 'concluida') continue;
      final pivo = op.pivoNome ?? 'Sem pivô';
      opsPorPivo.putIfAbsent(pivo, () => []).add(op);
    }

    final hoje = DateTime.now();
    DateTime? dataFimMaisTardia;
    int pivosEmParalelo = 0;

    for (var entry in opsPorPivo.entries) {
      final ops = entry.value;

      ops.sort((a, b) =>
          (a.diasAntesPlantio ?? 0).compareTo(b.diasAntesPlantio ?? 0));

      if (ops.isEmpty) continue;
      pivosEmParalelo++;

      DateTime? livreEm;
      for (var op in ops) {
        if (op.status != 'em_andamento') continue;
        if (op.dataInicioPrimeira == null) continue;
        final rendimento = op.rendimentoHaDia ?? 0;
        if (rendimento <= 0) continue;
        final area = (op.areaTotal ?? 0) * (op.numeroPassadas ?? 1);
        final duracao = area / rendimento;
        final fimPrevisto =
            op.dataInicioPrimeira!.add(Duration(days: duracao.ceil()));
        if (livreEm == null || fimPrevisto.isAfter(livreEm)) {
          livreEm = fimPrevisto;
        }
      }

      for (var op in ops) {
        final rendimento = op.rendimentoHaDia ?? 0;
        if (rendimento <= 0) continue;

        final area = (op.areaTotal ?? 0) * (op.numeroPassadas ?? 1);
        final duracaoDias = (area / rendimento).ceil();

        if (op.status == 'em_andamento' && op.dataInicioPrimeira != null) {
          final fim =
              op.dataInicioPrimeira!.add(Duration(days: duracaoDias));
          if (dataFimMaisTardia == null || fim.isAfter(dataFimMaisTardia)) {
            dataFimMaisTardia = fim;
          }
          continue;
        }

        final inicioJanela = op.getDataInicioJanelaCalculada();

        DateTime inicioReal;
        if (livreEm == null) {
          inicioReal = inicioJanela;
        } else {
          inicioReal =
              livreEm.isAfter(inicioJanela) ? livreEm : inicioJanela;
        }

        if (inicioReal.isBefore(hoje)) {
          inicioReal = hoje;
        }

        final fimReal = inicioReal.add(Duration(days: duracaoDias));
        livreEm = fimReal;

        if (dataFimMaisTardia == null || fimReal.isAfter(dataFimMaisTardia)) {
          dataFimMaisTardia = fimReal;
        }
      }
    }

    final diasAExecutar = dataFimMaisTardia == null
        ? 0
        : dataFimMaisTardia.difference(hoje).inDays;

    _insightsCache = {
      'totalRealizado': totalRealizado,
      'totalAExecutar': totalAExecutar,
      'diasAExecutar': diasAExecutar < 0 ? 0 : diasAExecutar,
      'capacidadeTotal': capacidadeTotal,
      'operacoesConcluidas': operacoesConcluidas,
      'operacoesPendentes': operacoesPendentes,
      'pivosEmParalelo': pivosEmParalelo,
    };
    return _insightsCache!;
  }

  Map<String, dynamic> get _progressoPivos {
    if (_progressoPivosCache != null) return _progressoPivosCache!;

    final Map<String, bool> prontoPorPivo = {};

    final Map<String, List<OperacaoExecutada>> todasPorPivo = {};
    for (final op in _operacoesFiltradas) {
      final pivo = op.pivoNome ?? 'Sem pivô';
      todasPorPivo.putIfAbsent(pivo, () => []).add(op);
    }

    todasPorPivo.forEach((pivo, ops) {
      if (ops.isEmpty) {
        prontoPorPivo[pivo] = false;
        return;
      }
      final todasFinalizadas = ops.every(
        (op) => op.status == 'concluida' || op.status == 'dispensada',
      );
      final temAndamento = ops.any((op) => op.status == 'em_andamento');
      prontoPorPivo[pivo] = todasFinalizadas && !temAndamento;
    });

    final Map<String, dynamic> resultado = {};
    final Set<String> pivosNoPeriodo = {};

    for (final op in _operacoesFiltradas) {
      final nomePivo = op.pivoNome ?? 'Sem pivô';
      pivosNoPeriodo.add(nomePivo);
    }

    for (final pivoNome in pivosNoPeriodo) {
      resultado[pivoNome] = {
        'nome': pivoNome,
        'plantio': null,
        'diasTotal': 0.0,
        'diasConcluido': 0.0,
        'diasAndamento': 0.0,
        'diasPlanejado': 0.0,
        'diasAtrasado': 0.0,
        'diasDispensado': 0.0,
        'operacoes': 0,
        'concluidas': 0,
        'andamento': 0,
        'planejadas': 0,
        'atrasadas': 0,
        'dispensadas': 0,
      };

      final operacoesPivo = _operacoesFiltradas
          .where((op) => op.pivoNome == pivoNome)
          .toList();

      for (final op in operacoesPivo) {
        if (op.dataPlantio != null) {
          resultado[pivoNome]['plantio'] = op.dataPlantio;
          break;
        }
      }

      for (final op in operacoesPivo) {
        final dias = op.getDiasNecessarios().toDouble();
        final item = resultado[pivoNome];
        item['operacoes']++;

        if (op.status != 'concluida' && op.status != 'dispensada') {
          item['diasTotal'] += dias;
        }

        switch (op.status) {
          case 'dispensada':
            item['diasDispensado'] += dias;
            item['dispensadas']++;
            break;
          case 'concluida':
            item['diasConcluido'] += dias;
            item['concluidas']++;
            break;
          case 'em_andamento':
            item['diasAndamento'] += dias;
            item['andamento']++;
            break;
          case 'atrasada':
            item['diasAtrasado'] += dias;
            item['atrasadas']++;
            break;
          default:
            item['diasPlanejado'] += dias;
            item['planejadas']++;
        }
      }

      final item = resultado[pivoNome];
      final operacoesExecutaveis =
          (item['operacoes'] as int) - (item['dispensadas'] as int);

      final percentualConcluido = operacoesExecutaveis == 0
          ? 0.0
          : (item['concluidas'] as int) / operacoesExecutaveis;
      final percentualAndamento = operacoesExecutaveis == 0
          ? 0.0
          : (item['andamento'] as int) / operacoesExecutaveis;
      final percentualAtrasado = operacoesExecutaveis == 0
          ? 0.0
          : (item['atrasadas'] as int) / operacoesExecutaveis;
      final percentualPlanejado = operacoesExecutaveis == 0
          ? 0.0
          : (item['planejadas'] as int) / operacoesExecutaveis;

      item['percentualConcluido'] = percentualConcluido;
      item['percentualAndamento'] = percentualAndamento;
      item['percentualAtrasado'] = percentualAtrasado;
      item['percentualPlanejado'] = percentualPlanejado;
      item['percentualExecutado'] = percentualConcluido + percentualAndamento;

      final opsOrdenadas = List<OperacaoExecutada>.from(operacoesPivo)
        ..sort((a, b) =>
            (a.diasAntesPlantio ?? 0).compareTo(b.diasAntesPlantio ?? 0));

      bool concluida(OperacaoExecutada op) => op.status == 'concluida';
      bool dispensada(OperacaoExecutada op) => op.status == 'dispensada';
      bool pendente(OperacaoExecutada op) =>
          !concluida(op) && !dispensada(op);

      OperacaoExecutada? anterior;
      for (int i = opsOrdenadas.length - 1; i >= 0; i--) {
        if (concluida(opsOrdenadas[i])) {
          anterior = opsOrdenadas[i];
          break;
        }
      }

      int idxUltimaConcluida = -1;
      for (int i = 0; i < opsOrdenadas.length; i++) {
        if (concluida(opsOrdenadas[i])) idxUltimaConcluida = i;
      }

      OperacaoExecutada? proxima;
      for (int i = idxUltimaConcluida + 1; i < opsOrdenadas.length; i++) {
        if (pendente(opsOrdenadas[i])) {
          proxima = opsOrdenadas[i];
          break;
        }
      }

      item['anterior'] = anterior?.operacaoNome;
      item['proxima'] = proxima?.operacaoNome;
      item['prontoParaPlantio'] = prontoPorPivo[pivoNome] ?? false;
    }

    final lista = resultado.values.toList();
    lista.sort((a, b) {
      final da = a['plantio'] as DateTime?;
      final db = b['plantio'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    _progressoPivosCache = {'lista': lista};
    return _progressoPivosCache!;
  }

  List<Map<String, dynamic>> get _pivosProntosParaPlantio {
    final lista = _progressoPivos['lista'] as List;
    final prontos = <Map<String, dynamic>>[];
    for (var item in lista) {
      if (item['prontoParaPlantio'] == true) {
        prontos.add({
          'nome': item['nome'],
          'plantio': item['plantio'],
          'concluidas': item['concluidas'],
          'operacoes': item['operacoes'],
          'anterior': item['anterior'],
        });
      }
    }
    prontos.sort((a, b) {
      final da = a['plantio'] as DateTime?;
      final db = b['plantio'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return prontos;
  }

  String _formatarDataComAno(DateTime? data) {
    if (data == null) return '---';
    try {
      return '${data.day}/${data.month}/${data.year}';
    } catch (e) {
      return 'Data inválida';
    }
  }

  String _formatarDataCurta(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarDados() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await widget.service.carregarOperacoes();
      _invalidarCaches();
      _anosSafraDisponiveisCache = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verificarOperacoesAtrasadas() async {
    List<OperacaoExecutada> operacoesParaCorrigir = [];

    for (var op in widget.service.operacoes) {
      if (op.isRealmenteAtrasada && op.status != 'atrasada') {
        operacoesParaCorrigir.add(op);
      }
    }

    if (operacoesParaCorrigir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Nenhuma operação inconsistente encontrada'),
        ),
      );
      return;
    }

    operacoesParaCorrigir.sort((a, b) {
      final da = a.getDataFimJanelaCalculada();
      final db = b.getDataFimJanelaCalculada();
      return da.compareTo(db);
    });

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: _cores['Atrasada'],
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Operações Atrasadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _neutroTexto,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _cores['Atrasada']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${operacoesParaCorrigir.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _cores['Atrasada'],
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: operacoesParaCorrigir.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final op = operacoesParaCorrigir[index];
              final fim = op.getDataFimJanelaCalculada();
              final diasAtraso = DateTime.now().difference(fim).inDays;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _cores['Atrasada'],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.operacaoNome ?? 'Operação',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _neutroTexto,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            op.pivoNome ?? 'Sem pivô',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _neutroTextoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$diasAtraso d',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _cores['Atrasada'],
                          ),
                        ),
                        Text(
                          'Limite: ${_formatarDataComAno(fim)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: _neutroTextoSuave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _neutroTextoSuave,
            ),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _gerarRelatorioPDF() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final nomeUsuario =
          authProvider.currentEmail?.split('@').first ?? 'Usuário';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Gerando relatório PDF...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pdfService = PdfService();

      await pdfService.gerarRelatorioOperacoes(
        operacoes: _operacoesFiltradas,
        resumo: _resumo,
        insights: _insights,
        pivosProntosParaPlantio: _pivosProntosParaPlantio,
        filtroPivo: _filtroPivo,
        filtroOperacao: _filtroOperacao,
        filtroData: (_dataInicio != null && _dataFim != null)
            ? DateTimeRange(start: _dataInicio!, end: _dataFim!)
            : null,
        nomeUsuario: nomeUsuario,
        dataGeracao: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Relatório PDF gerado com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao gerar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _toggleSecao(String key) {
    setState(() {
      _secoesExpandidas[key] = !(_secoesExpandidas[key] ?? false);
    });
  }

  bool _isSecaoExpandida(String key) => _secoesExpandidas[key] ?? false;

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;
    final insights = _insights;
    final total = resumo.values.fold(0, (a, b) => a + b);
    final pivos = ['Todos', ...widget.service.getPivosUnicos()];
    final operacoesLista = ['Todas', ...widget.service.getOperacoesUnicas()];

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: Stack(
        children: [
          if (_isLoading || _isGeneratingPdf)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFiltros(pivos, operacoesLista),
                const SizedBox(height: 16),
                _buildCardProntosParaPlantio(),
                const SizedBox(height: 12),
                _buildCards(resumo),
                const SizedBox(height: 20),
                _buildSecaoRecolhivel(
                  chave: 'grafico',
                  titulo: 'Distribuição por Status',
                  icone: Icons.pie_chart_outline,
                  cor: _neutroTexto,
                  child: _buildGrafico(resumo, total),
                ),
                const SizedBox(height: 16),
                _buildSecaoRecolhivel(
                  chave: 'insights',
                  titulo: 'Insights Operacionais',
                  icone: Icons.insights_outlined,
                  cor: _neutroTexto,
                  child: _buildInsights(insights),
                ),
                const SizedBox(height: 16),
                _buildResumoPlantios(),
                const SizedBox(height: 16),
                _buildSecaoOperacoes('Concluído', 'Concluídas',
                    _cores['Concluído']!),
                const SizedBox(height: 16),
                _buildSecaoOperacoes('Em andamento', 'Em andamento',
                    _cores['Em andamento']!),
                const SizedBox(height: 16),
                _buildSecaoOperacoes('Planejada', 'Planejadas',
                    _cores['Planejada']!),
                const SizedBox(height: 16),
                _buildSecaoOperacoes('Atrasada', 'Atrasadas',
                    _cores['Atrasada']!),
                const SizedBox(height: 16),
                _buildSecaoOperacoes('Dispensada', 'Dispensadas',
                    _cores['Dispensada']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardProntosParaPlantio() {
    final prontos = _pivosProntosParaPlantio;
    final totalProntos = prontos.length;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _neutroBorda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _cores['Concluído'],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$totalProntos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _neutroTexto,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              totalProntos == 1
                  ? 'pivô pronto para plantio'
                  : 'pivôs prontos para plantio',
              style: const TextStyle(
                fontSize: 12,
                color: _neutroTextoSuave,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoRecolhivel({
    required String chave,
    required String titulo,
    required IconData icone,
    required Color cor,
    required Widget child,
  }) {
    final isExpanded = _isSecaoExpandida(chave);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutroBorda),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSecao(chave),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(icone, color: cor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _neutroTexto,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _neutroIcone,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: child,
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTROS
  // ============================================================

  Widget _buildFiltros(List<String> pivos, List<String> operacoesLista) {
    final anos = _anosSafraDisponiveis;
    final anoAtualValido =
        _filtroAnoSafra != null && anos.contains(_filtroAnoSafra);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _neutroBorda),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildFiltroChip(
              leading: const Icon(
                Icons.grass_outlined,
                size: 13,
                color: _neutroIcone,
              ),
              valor: _filtroPivo != 'Todos' ? _filtroPivo : 'Pivôs',
              ativo: _filtroPivo != 'Todos',
              onTap: () => _abrirMenuFiltro(
                titulo: 'Pivô',
                opcoes: pivos,
                valorAtual: _filtroPivo,
                onSelecionar: (v) {
                  setState(() {
                    _filtroPivo = v;
                    _expandedPivos.clear();
                    _invalidarCaches();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildFiltroChip(
              leading: const Text('🚜', style: TextStyle(fontSize: 13)),
              valor:
                  _filtroOperacao != 'Todas' ? _filtroOperacao : 'Operações',
              ativo: _filtroOperacao != 'Todas',
              onTap: () => _abrirMenuFiltro(
                titulo: 'Operação',
                opcoes: operacoesLista,
                valorAtual: _filtroOperacao,
                onSelecionar: (v) {
                  setState(() {
                    _filtroOperacao = v;
                    _expandedPivos.clear();
                    _invalidarCaches();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildFiltroChip(
              leading: const Icon(
                Icons.eco_outlined,
                size: 13,
                color: _neutroIcone,
              ),
              valor: anoAtualValido ? _filtroAnoSafra! : 'Safras',
              ativo: anoAtualValido,
              onTap: () => _abrirMenuAnoSafra(anos),
              onClear: anoAtualValido
                  ? () {
                      setState(() {
                        _filtroAnoSafra = null;
                        _expandedPivos.clear();
                        _invalidarCaches();
                      });
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildFiltroChip(
              leading: const Icon(
                Icons.event_outlined,
                size: 13,
                color: _neutroIcone,
              ),
              valor: _dataInicio != null
                  ? _formatarDataCurta(_dataInicio!)
                  : 'De',
              ativo: _dataInicio != null,
              onTap: () => _selecionarDataInicio(),
              onClear: _dataInicio != null
                  ? () {
                      setState(() {
                        _dataInicio = null;
                        _expandedPivos.clear();
                        _anosSafraDisponiveisCache = null;
                        _invalidarCaches();
                      });
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildFiltroChip(
              leading: const Icon(
                Icons.event_available_outlined,
                size: 13,
                color: _neutroIcone,
              ),
              valor: _dataFim != null
                  ? _formatarDataCurta(_dataFim!)
                  : 'Até',
              ativo: _dataFim != null,
              onTap: () => _selecionarDataFim(),
              onClear: _dataFim != null
                  ? () {
                      setState(() {
                        _dataFim = null;
                        _expandedPivos.clear();
                        _anosSafraDisponiveisCache = null;
                        _invalidarCaches();
                      });
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          _buildAcaoIcone(
            icone: Icons.picture_as_pdf_outlined,
            tooltip: 'Gerar relatório PDF',
            onTap: _isGeneratingPdf ? null : _gerarRelatorioPDF,
          ),
          _buildAcaoIcone(
            icone: Icons.warning_amber_outlined,
            tooltip: 'Verificar operações atrasadas',
            onTap: _verificarOperacoesAtrasadas,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip({
    required Widget leading,
    required String valor,
    required bool ativo,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? _destaqueFundo : _neutroFundo,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ativo ? _destaqueBorda : _neutroBorda,
          ),
        ),
        child: Row(
          children: [
            if (ativo)
              Icon(Icons.circle, size: 8, color: _destaque)
            else
              leading,
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 12,
                  color: ativo ? _destaque : _neutroTexto,
                  fontWeight: ativo ? FontWeight.w500 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: ativo ? _destaque : _neutroIcone,
                  ),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: ativo ? _destaque : _neutroIcone,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcaoIcone({
    required IconData icone,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icone,
            size: 16,
            color: onTap == null ? _neutroBorda : _neutroIcone,
          ),
        ),
      ),
    );
  }

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Data inicial',
    );
    if (picked != null) {
      setState(() {
        _dataInicio = picked;
        if (_dataFim != null && _dataFim!.isBefore(picked)) {
          _dataFim = picked;
        }
        _expandedPivos.clear();
        _anosSafraDisponiveisCache = null;
        _invalidarCaches();
      });
    }
  }

  Future<void> _selecionarDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Data final',
    );
    if (picked != null) {
      setState(() {
        _dataFim = picked;
        if (_dataInicio != null && _dataInicio!.isAfter(picked)) {
          _dataInicio = picked;
        }
        _expandedPivos.clear();
        _anosSafraDisponiveisCache = null;
        _invalidarCaches();
      });
    }
  }

  Future<void> _abrirMenuAnoSafra(List<String> anos) async {
    if (anos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma safra no período selecionado'),
        ),
      );
      return;
    }

    final selecionado = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _neutroBorda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ano safra',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _neutroTexto,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 0),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: anos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSel = _filtroAnoSafra == null;
                      return ListTile(
                        dense: true,
                        title: Text(
                          'Todas as safras',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSel ? _destaque : _neutroTexto,
                            fontWeight:
                                isSel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(Icons.check,
                                size: 18, color: _destaque)
                            : null,
                        onTap: () => Navigator.pop(context, '__TODAS__'),
                      );
                    }
                    final ano = anos[index - 1];
                    final isSel = ano == _filtroAnoSafra;
                    return ListTile(
                      dense: true,
                      title: Text(
                        ano,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSel ? _destaque : _neutroTexto,
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check,
                              size: 18, color: _destaque)
                          : null,
                      onTap: () => Navigator.pop(context, ano),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selecionado == null) return;

    setState(() {
      _filtroAnoSafra = (selecionado == '__TODAS__') ? null : selecionado;
      _expandedPivos.clear();
      _invalidarCaches();
    });
  }

  Future<void> _abrirMenuFiltro({
    required String titulo,
    required List<String> opcoes,
    required String valorAtual,
    required ValueChanged<String> onSelecionar,
  }) async {
    final selecionado = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _neutroBorda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _neutroTexto,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 0),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: opcoes.length,
                  itemBuilder: (context, index) {
                    final opcao = opcoes[index];
                    final estaSelecionado = opcao == valorAtual;
                    return ListTile(
                      dense: true,
                      title: Text(
                        opcao,
                        style: TextStyle(
                          fontSize: 14,
                          color: estaSelecionado
                              ? _destaque
                              : _neutroTexto,
                          fontWeight: estaSelecionado
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: estaSelecionado
                          ? const Icon(Icons.check, size: 18, color: _destaque)
                          : null,
                      onTap: () => Navigator.pop(context, opcao),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selecionado != null) {
      onSelecionar(selecionado);
    }
  }

  // ============================================================
  // CARDS DE STATUS
  // ============================================================

  Widget _buildCards(Map<String, int> resumo) {
    return Row(
      children: [
        _card('Concluído', resumo['Concluído'] ?? 0, _cores['Concluído']!),
        _card(
          'Em andamento',
          resumo['Em andamento'] ?? 0,
          _cores['Em andamento']!,
        ),
        _card('Planejada', resumo['Planejada'] ?? 0, _cores['Planejada']!),
        _card('Atrasada', resumo['Atrasada'] ?? 0, _cores['Atrasada']!),
        _card('Dispensada', resumo['Dispensada'] ?? 0, _cores['Dispensada']!),
      ],
    );
  }

  Widget _card(String status, int valor, Color cor) {
    return Expanded(
      child: Container(
        height: 76,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _neutroBorda),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: const TextStyle(
                    color: _neutroTextoSuave,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              valor.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _neutroTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafico(Map<String, int> resumo, int total) {
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: total == 0
              ? const Center(
                  child: Text(
                    'Nenhum dado',
                    style: TextStyle(color: _neutroTextoSuave),
                  ),
                )
              : Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: _PieChartPainter(resumo, _cores, total),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _cores.entries.map((entry) {
            final count = resumo[entry.key] ?? 0;
            if (count == 0) return const SizedBox.shrink();
            final percent = (count / total) * 100;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${entry.key} · $count (${percent.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _neutroTextoSuave,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInsights(Map<String, dynamic> insights) {
    final pivos = insights['pivosEmParalelo'] as int;
    final capacidade = insights['capacidadeTotal'] as double;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  icon: Icons.check_circle_outline,
                  titulo: 'Total Realizado',
                  valor: '${insights['totalRealizado'].toStringAsFixed(0)} ha',
                  cor: _cores['Concluído']!,
                  subtitle:
                      '${insights['operacoesConcluidas']} operações concluídas',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  icon: Icons.schedule_outlined,
                  titulo: 'Total a Executar',
                  valor: '${insights['totalAExecutar'].toStringAsFixed(0)} ha',
                  cor: _cores['Planejada']!,
                  subtitle:
                      '${insights['operacoesPendentes']} operações pendentes',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  icon: Icons.calendar_today_outlined,
                  titulo: 'Tempo Necessário',
                  valor: '${insights['diasAExecutar']} dias',
                  cor: _cores['Em andamento']!,
                  subtitle: pivos == 0
                      ? 'Sem operações pendentes'
                      : '$pivos pivô(s) em paralelo',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  icon: Icons.speed_outlined,
                  titulo: 'Capacidade Total',
                  valor: '${capacidade.toStringAsFixed(1)} ha/dia',
                  cor: _neutroTexto,
                  subtitle: _filtroPivo != 'Todos'
                      ? 'Gargalo do pivô'
                      : 'Soma das operações padrão',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoPlantios() {
    final lista = _progressoPivos['lista'] as List;
    const chave = 'resumoPlantios';
    final isExpanded = _isSecaoExpandida(chave);

    if (lista.isEmpty) {
      return const SizedBox.shrink();
    }

    int totalOperacoes = 0;
    for (var item in lista) {
      totalOperacoes += item['operacoes'] as int;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutroBorda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSecao(chave),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.agriculture_outlined,
                    color: _neutroTexto,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Andamento das operações de preparo do solo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _neutroTexto,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _neutroFundo,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _neutroBorda),
                    ),
                    child: Text(
                      '$totalOperacoes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _neutroTextoSuave,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _neutroIcone,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: lista.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final pivoNome = item['nome'] as String;
                final isExpandedPivo =
                    _expandedPivos['plantio_$pivoNome'] ?? false;

                final total = item['diasTotal'] as double;

                final concluido = item['percentualConcluido'] as double? ?? 0.0;
                final andamento = item['percentualAndamento'] as double? ?? 0.0;
                final atrasado = item['percentualAtrasado'] as double? ?? 0.0;
                final planejado = item['percentualPlanejado'] as double? ?? 0.0;
                final executado = item['percentualExecutado'] as double? ?? 0.0;

                final operacoesCount = item['operacoes'] as int;
                final concluidasCount = item['concluidas'] as int;
                final andamentoCount = item['andamento'] as int;
                final planejadasCount = item['planejadas'] as int;
                final atrasadasCount = item['atrasadas'] as int;
                final dispensadasCount = item['dispensadas'] as int;
                final operacoesExecutaveis =
                    operacoesCount - dispensadasCount;

                final dataPlantio = item['plantio'] as DateTime?;
                final anterior = item['anterior'] as String?;
                final proxima = item['proxima'] as String?;

                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        _expandedPivos['plantio_$pivoNome'] = !isExpandedPivo;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isExpandedPivo
                              ? _neutroFundo
                              : Colors.transparent,
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  isExpandedPivo
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: _neutroIcone,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),

                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    anterior ?? 'Nenhuma operação',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: anterior != null
                                          ? _neutroTexto
                                          : _neutroTextoSuave,
                                      fontStyle: anterior == null
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 4),
                                Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _neutroBorda,
                                  ),
                                ),
                                const SizedBox(width: 4),

                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    pivoNome,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _neutroTexto,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 4),
                                Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _neutroBorda,
                                  ),
                                ),
                                const SizedBox(width: 4),

                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    proxima ?? 'Pronto para plantio',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: proxima != null
                                          ? _neutroTexto
                                          : _cores['Concluído'],
                                      fontWeight: proxima != null
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 52),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              '$concluidasCount de $operacoesExecutaveis concluídas · '
                              '$andamentoCount em andamento · '
                              '$planejadasCount planejadas · '
                              '$atrasadasCount atrasadas'
                              '${dispensadasCount > 0 ? ' · $dispensadasCount dispensadas' : ''}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _neutroTextoSuave,
                              ),
                            ),

                            if (dataPlantio != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Plantio: ${_formatarDataComAno(dataPlantio)} '
                                  '(${dataPlantio.difference(DateTime.now()).inDays} dias)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: dataPlantio
                                                .difference(DateTime.now())
                                                .inDays <
                                            15
                                        ? _cores['Atrasada']
                                        : _neutroTextoSuave,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpandedPivo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 0),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 20,
                                child: Row(
                                  children: [
                                    if (concluido > 0)
                                      Expanded(
                                        flex: (concluido * 1000).round(),
                                        child: Container(
                                          color: _cores['Concluído'],
                                        ),
                                      ),
                                    if (andamento > 0)
                                      Expanded(
                                        flex: (andamento * 1000).round(),
                                        child: Container(
                                          color: _cores['Em andamento'],
                                        ),
                                      ),
                                    if (atrasado > 0)
                                      Expanded(
                                        flex: (atrasado * 1000).round(),
                                        child: Container(
                                          color: _cores['Atrasada'],
                                        ),
                                      ),
                                    if (planejado > 0)
                                      Expanded(
                                        flex: (planejado * 1000).round(),
                                        child: Container(
                                          color: _cores['Planejada'],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _legendaNeutra(
                                  _cores['Concluído']!,
                                  'Concluído',
                                  concluidasCount,
                                ),
                                _legendaNeutra(
                                  _cores['Em andamento']!,
                                  'Em andamento',
                                  andamentoCount,
                                ),
                                _legendaNeutra(
                                  _cores['Atrasada']!,
                                  'Atrasado',
                                  atrasadasCount,
                                ),
                                _legendaNeutra(
                                  _cores['Planejada']!,
                                  'Planejado',
                                  planejadasCount,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _neutroFundo,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _neutroBorda),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _metricaNeutra(
                                    'Total dias',
                                    '${total.toStringAsFixed(0)}',
                                  ),
                                  _metricaNeutra(
                                    'Concluídos',
                                    '$concluidasCount/$operacoesExecutaveis',
                                  ),
                                  _metricaNeutra(
                                    'Execução',
                                    '${(executado * 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (index < lista.length - 1)
                      const Divider(height: 0, indent: 16),
                  ],
                );
              }).toList(),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _legendaNeutra(Color cor, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label · $count',
          style: const TextStyle(
            fontSize: 11,
            color: _neutroTextoSuave,
          ),
        ),
      ],
    );
  }

  Widget _metricaNeutra(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _neutroTexto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _neutroTextoSuave,
          ),
        ),
      ],
    );
  }

  Widget _insightCard({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color cor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _neutroBorda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _neutroTextoSuave,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _neutroTexto,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: _neutroTextoSuave,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecaoOperacoes(
    String status,
    String tituloPlural,
    Color cor,
  ) {
    final chave = 'ops_$tituloPlural';
    final isExpanded = _isSecaoExpandida(chave);

    List<OperacaoExecutada> operacoesStatus = [];
    for (var op in _operacoesFiltradas) {
      if (op.getStatusText() == status) {
        operacoesStatus.add(op);
      }
    }

    operacoesStatus.sort((a, b) {
      DateTime? dataA;
      DateTime? dataB;

      if (a.status == 'concluida') {
        dataA = a.dataFimUltima;
      } else {
        dataA = a.getDataInicioJanelaCalculada();
      }

      if (b.status == 'concluida') {
        dataB = b.dataFimUltima;
      } else {
        dataB = b.getDataInicioJanelaCalculada();
      }

      final dateA = dataA ?? DateTime(3000);
      final dateB = dataB ?? DateTime(3000);
      return dateA.compareTo(dateB);
    });

    final Map<String, List<OperacaoExecutada>> operacoesPorPivo = {};
    for (var op in operacoesStatus) {
      final pivo = op.pivoNome ?? 'Sem Pivô';
      operacoesPorPivo.putIfAbsent(pivo, () => []).add(op);
    }

    final pivosLista = operacoesPorPivo.keys.toList()..sort();
    final totalOperacoes = operacoesStatus.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutroBorda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSecao(chave),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Operações $tituloPlural',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _neutroTexto,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _neutroFundo,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _neutroBorda),
                    ),
                    child: Text(
                      '$totalOperacoes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _neutroTextoSuave,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _neutroIcone,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: pivosLista.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Nenhuma operação',
                        style: TextStyle(color: _neutroTextoSuave),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pivosLista.length,
                    itemBuilder: (context, index) {
                      final pivoNome = pivosLista[index];
                      final operacoes = operacoesPorPivo[pivoNome]!;
                      final isExpandedPivo =
                          _expandedPivos['${tituloPlural}_$pivoNome'] ?? false;

                      double areaTotalPivo = 0;
                      int diasTotaisPivo = 0;
                      for (var op in operacoes) {
                        areaTotalPivo += op.areaTotal ?? 0;
                        diasTotaisPivo += op.getDiasNecessarios();
                      }

                      return Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _expandedPivos[
                                      '${tituloPlural}_$pivoNome'] =
                                  !isExpandedPivo,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isExpandedPivo
                                    ? _neutroFundo
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isExpandedPivo
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: _neutroIcone,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pivoNome,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _neutroTexto,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${operacoes.length} operações · ${areaTotalPivo.toStringAsFixed(0)} ha${status != 'Concluído' && status != 'Dispensada' ? ' · $diasTotaisPivo dias' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _neutroTextoSuave,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpandedPivo)
                            Column(
                              children: [
                                const Divider(height: 0, indent: 16),
                                ...operacoes.map(
                                  (op) => _buildOperacaoTile(op, cor),
                                ),
                              ],
                            ),
                          if (index < pivosLista.length - 1)
                            const Divider(height: 0, indent: 16),
                        ],
                      );
                    },
                  ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildOperacaoTile(OperacaoExecutada op, Color cor) {
    final diasNecessarios = op.getDiasNecessarios();
    final areaTotalComPassadas = op.getAreaTotalComPassadas();
    final tempoPrevisto =
        diasNecessarios == 1 ? '1 dia' : '$diasNecessarios dias';
    final dataInicioJanela = op.getDataInicioJanelaCalculada();
    final dataFimJanela = op.getDataFimJanelaCalculada();
    final dataInicio = op.dataInicioPrimeira;
    final dataConclusao = op.dataFimUltima;
    final isInconsistente = op.isRealmenteAtrasada;
    final mensagemAlerta = op.mensagemInconsistencia;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isInconsistente
            ? _cores['Atrasada']!.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isInconsistente
            ? Border.all(color: _cores['Atrasada']!.withOpacity(0.3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 68,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          op.operacaoNome ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _neutroTexto,
                            decoration: op.status == 'dispensada'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (isInconsistente)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _cores['Atrasada']!.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Atrasada',
                            style: TextStyle(
                              color: _cores['Atrasada'],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (mensagemAlerta != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      mensagemAlerta,
                      style: TextStyle(
                        fontSize: 10,
                        color: _cores['Atrasada'],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _infoNeutro(
                        Icons.square_foot_outlined,
                        '${areaTotalComPassadas.toStringAsFixed(0)} ha (${op.numeroPassadas}x)',
                      ),
                      _infoNeutro(
                        Icons.speed_outlined,
                        '${op.rendimentoHaDia?.toStringAsFixed(1)} ha/dia',
                      ),
                      if (op.status != 'dispensada' &&
                          op.status != 'concluida')
                        _infoNeutro(Icons.timer_outlined, tempoPrevisto),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _infoNeutro(
                    Icons.date_range_outlined,
                    'Janela: ${_formatarDataComAno(dataInicioJanela)} a ${_formatarDataComAno(dataFimJanela)}',
                    destaque: isInconsistente,
                  ),
                  if (op.status == 'em_andamento' && dataInicio != null) ...[
                    const SizedBox(height: 4),
                    _infoNeutro(
                      Icons.play_arrow_outlined,
                      'Iniciado em: ${_formatarDataComAno(dataInicio)}',
                    ),
                  ],
                  if (op.status == 'concluida') ...[
                    if (dataInicio != null) ...[
                      const SizedBox(height: 4),
                      _infoNeutro(
                        Icons.play_arrow_outlined,
                        'Iniciado em: ${_formatarDataComAno(dataInicio)}',
                      ),
                    ],
                    if (dataConclusao != null) ...[
                      const SizedBox(height: 2),
                      _infoNeutro(
                        Icons.check_circle_outline,
                        'Concluído em: ${_formatarDataComAno(dataConclusao)}',
                      ),
                    ],
                  ],
                  if (op.numeroPassadas != null &&
                      op.numeroPassadas! > 1 &&
                      op.status != 'concluida' &&
                      op.status != 'dispensada') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Múltiplas passadas necessárias',
                      style: TextStyle(
                        fontSize: 10,
                        color: _cores['Planejada']!.withOpacity(0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoNeutro(
    IconData icon,
    String label, {
    bool destaque = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: destaque ? _cores['Atrasada'] : _neutroIcone,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: destaque ? _cores['Atrasada'] : _neutroTextoSuave,
            fontWeight: destaque ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> dados;
  final Map<String, Color> cores;
  final int total;

  _PieChartPainter(this.dados, this.cores, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;
    double startAngle = -pi / 2;
    final statuses = [
      'Concluído',
      'Em andamento',
      'Planejada',
      'Atrasada',
      'Dispensada',
    ];

    for (var status in statuses) {
      final value = dados[status] ?? 0;
      if (value == 0) continue;

      final sweep = (value / total) * 2 * pi;
      final color = cores[status]!;
      final percent = (value / total) * 100;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        Paint()..color = color,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      if (percent > 5) {
        final midAngle = startAngle + sweep / 2;
        final textRadius = radius * 0.65;
        final textOffset = Offset(
          center.dx + cos(midAngle) * textRadius,
          center.dy + sin(midAngle) * textRadius,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: "${percent.toStringAsFixed(0)}%",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        final textRect = Rect.fromCenter(
          center: textOffset,
          width: tp.width + 6,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(textRect, const Radius.circular(4)),
          Paint()..color = Colors.black.withOpacity(0.4),
        );
        tp.paint(
          canvas,
          Offset(textOffset.dx - tp.width / 2, textOffset.dy - tp.height / 2),
        );
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.dados != dados ||
        oldDelegate.cores != cores;
  }
}