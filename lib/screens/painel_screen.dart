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
  DateTimeRange? _filtroData;
  Map<String, bool> _expandedPivos = {};
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  final Map<String, Color> _cores = {
    'Concluído': const Color(0xFF22C55E),
    'Em andamento': const Color(0xFF3B82F6),
    'Planejada': const Color(0xFFFACC15),
    'Atrasada': const Color(0xFFEF4444),
    'Dispensada': Colors.grey,
  };

  List<OperacaoExecutada> get _operacoesFiltradas {
    var operacoes = widget.service.operacoes.where((op) {
      if (_filtroPivo != 'Todos' && op.pivoNome != _filtroPivo) return false;
      if (_filtroOperacao != 'Todas' && op.operacaoNome != _filtroOperacao) return false;
      
      if (_filtroData != null) {
        if (op.status == 'concluida' && op.dataFimUltima != null) {
          final dataConclusao = op.dataFimUltima!;
          if (dataConclusao.isBefore(_filtroData!.start) || dataConclusao.isAfter(_filtroData!.end)) {
            return false;
          }
        } else {
          final inicioJanela = op.getDataInicioJanelaCalculada();
          final fimJanela = op.getDataFimJanelaCalculada();
          if (fimJanela.isBefore(_filtroData!.start) || inicioJanela.isAfter(_filtroData!.end)) {
            return false;
          }
        }
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
    final resumo = {'Concluído': 0, 'Em andamento': 0, 'Planejada': 0, 'Atrasada': 0, 'Dispensada': 0};
    for (var op in _operacoesFiltradas) {
      resumo[op.getStatusText()] = (resumo[op.getStatusText()] ?? 0) + 1;
    }
    return resumo;
  }

  Map<String, dynamic> get _insights {
    double totalRealizado = 0;
    double totalAExecutar = 0;
    double rendimentoTotal = 0;
    int operacoesConcluidas = 0;
    int operacoesPendentes = 0;
    int operacoesComRendimento = 0;
    
    for (var op in _operacoesFiltradas) {
      if (op.status == 'dispensada') continue;
      
      if (op.status == 'concluida') {
        totalRealizado += op.areaTotal ?? 0;
        operacoesConcluidas++;
      } else {
        totalAExecutar += op.areaTotal ?? 0;
        if (op.rendimentoHaDia != null && op.rendimentoHaDia! > 0) {
          rendimentoTotal += op.rendimentoHaDia!;
          operacoesComRendimento++;
        }
        operacoesPendentes++;
      }
    }
    
    final rendimentoMedio = operacoesComRendimento > 0 ? rendimentoTotal / operacoesComRendimento : 0;
    final diasAExecutar = rendimentoMedio > 0 ? (totalAExecutar / rendimentoMedio).ceil() : 0;
    
    return {
      'totalRealizado': totalRealizado,
      'totalAExecutar': totalAExecutar,
      'diasAExecutar': diasAExecutar,
      'rendimentoMedio': rendimentoMedio,
      'operacoesConcluidas': operacoesConcluidas,
      'operacoesPendentes': operacoesPendentes,
    };
  }

  String _formatarDataComAno(DateTime? data) {
    if (data == null) return '---';
    return '${data.day}/${data.month}/${data.year}';
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
        const SnackBar(content: Text('✅ Nenhuma operação inconsistente encontrada')),
      );
      return;
    }
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Operações Atrasadas Detectadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encontradas ${operacoesParaCorrigir.length} operações que estão fora da janela:'),
            const SizedBox(height: 12),
            ...operacoesParaCorrigir.map((op) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${op.operacaoNome} - ${op.pivoNome}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            const Text('Deseja marcar todas como ATRASADAS?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Marcar Todas'),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      setState(() => _isLoading = true);
      
      for (var op in operacoesParaCorrigir) {
        await widget.service.atualizarStatus(op, 'atrasada');
      }
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${operacoesParaCorrigir.length} operações marcadas como atrasadas')),
      );
    }
  }

  Future<void> _gerarRelatorioPDF() async {
    setState(() => _isGeneratingPdf = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final nomeUsuario = authProvider.currentEmail?.split('@').first ?? 'Usuário';
      
      final pdfService = PdfService();
      
      await pdfService.gerarRelatorioOperacoes(
        operacoes: _operacoesFiltradas,
        resumo: _resumo,
        insights: _insights,
        filtroPivo: _filtroPivo,
        filtroOperacao: _filtroOperacao,
        filtroData: _filtroData,
        nomeUsuario: nomeUsuario,
        dataGeracao: DateTime.now(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Relatório PDF gerado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao gerar relatório: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;
    final insights = _insights;
    final total = resumo.values.fold(0, (a, b) => a + b);
    final pivos = ['Todos', ...widget.service.getPivosUnicos()];
    final operacoesLista = ['Todas', ...widget.service.getOperacoesUnicas()];

    return RefreshIndicator(
      onRefresh: () => widget.service.carregarOperacoes(),
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
                const SizedBox(height: 25),
                _buildCards(resumo),
                const SizedBox(height: 25),
                _buildGrafico(resumo, total),
                const SizedBox(height: 25),
                _buildInsights(insights),
                const SizedBox(height: 25),
                _buildSecaoOperacoes('Concluído', _cores['Concluído']!),
                const SizedBox(height: 20),
                _buildSecaoOperacoes('Em andamento', _cores['Em andamento']!),
                const SizedBox(height: 20),
                _buildSecaoOperacoes('Planejada', _cores['Planejada']!),
                const SizedBox(height: 20),
                _buildSecaoOperacoes('Atrasada', _cores['Atrasada']!),
                const SizedBox(height: 20),
                _buildSecaoOperacoes('Dispensada', _cores['Dispensada']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(List<String> pivos, List<String> operacoesLista) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: _isGeneratingPdf ? null : _gerarRelatorioPDF,
                      tooltip: 'Gerar Relatório PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.warning_amber, color: Colors.orange),
                      onPressed: _verificarOperacoesAtrasadas,
                      tooltip: 'Verificar operações atrasadas',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pivô', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _filtroPivo,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: pivos.map((pivo) => DropdownMenuItem(value: pivo, child: Text(pivo))).toList(),
                            onChanged: (value) => setState(() {
                              _filtroPivo = value!;
                              _expandedPivos.clear();
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Operação', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _filtroOperacao,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: operacoesLista.map((op) => DropdownMenuItem(value: op, child: Text(op))).toList(),
                            onChanged: (value) => setState(() {
                              _filtroOperacao = value!;
                              _expandedPivos.clear();
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDataFilter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataFilter() {
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime(2027),
          initialDateRange: _filtroData,
        );
        if (picked != null) {
          setState(() {
            _filtroData = picked;
            _expandedPivos.clear();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _filtroData == null 
                    ? 'Selecionar período'
                    : '${_formatarDataComAno(_filtroData!.start)} - ${_formatarDataComAno(_filtroData!.end)}',
                style: TextStyle(fontSize: 14, color: _filtroData == null ? Colors.grey[600] : Colors.black87),
              ),
            ),
            if (_filtroData != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _filtroData = null;
                    _expandedPivos.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCards(Map<String, int> resumo) {
    return Row(
      children: [
        _card('Concluído', resumo['Concluído'] ?? 0, _cores['Concluído']!),
        _card('Em andamento', resumo['Em andamento'] ?? 0, _cores['Em andamento']!),
        _card('Planejada', resumo['Planejada'] ?? 0, _cores['Planejada']!),
        _card('Atrasada', resumo['Atrasada'] ?? 0, _cores['Atrasada']!),
        _card('Dispensada', resumo['Dispensada'] ?? 0, _cores['Dispensada']!),
      ],
    );
  }

  Widget _card(String status, int valor, Color cor) {
    return Expanded(
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 11)),
            const SizedBox(height: 4),
            Text(valor.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafico(Map<String, int> resumo, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4)],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Distribuição por Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const Divider(height: 0),
          SizedBox(
            height: 280,
            child: total == 0
                ? const Center(child: Text('Nenhum dado', style: TextStyle(color: Colors.grey)))
                : Center(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(painter: _PieChartPainter(resumo, _cores, total)),
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
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: entry.value.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${entry.key}: $count (${percent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(Map<String, dynamic> insights) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text('Insights Operacionais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _insightCard(icon: Icons.check_circle, titulo: 'Total Realizado', valor: '${insights['totalRealizado'].toStringAsFixed(0)} ha', cor: Colors.green, subtitle: '${insights['operacoesConcluidas']} operações concluídas')),
              const SizedBox(width: 12),
              Expanded(child: _insightCard(icon: Icons.schedule, titulo: 'Total a Executar', valor: '${insights['totalAExecutar'].toStringAsFixed(0)} ha', cor: Colors.orange, subtitle: '${insights['operacoesPendentes']} operações pendentes')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _insightCard(icon: Icons.calendar_today, titulo: 'Tempo Necessário', valor: '${insights['diasAExecutar']} dias', cor: Colors.blue, subtitle: 'Considerando rendimento médio')),
              const SizedBox(width: 12),
              Expanded(child: _insightCard(icon: Icons.trending_up, titulo: 'Rendimento Médio', valor: '${insights['rendimentoMedio'].toStringAsFixed(1)} ha/dia', cor: Colors.purple, subtitle: 'Baseado nas operações')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard({required IconData icon, required String titulo, required String valor, required Color cor, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: cor.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            ],
          ),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
        ],
      ),
    );
  }

  Widget _buildSecaoOperacoes(String status, Color cor) {
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Operações $status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: cor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('$totalOperacoes operações', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ),
              ],
            ),
          ),
          if (pivosLista.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Nenhuma operação', style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pivosLista.length,
              itemBuilder: (context, index) {
                final pivoNome = pivosLista[index];
                final operacoes = operacoesPorPivo[pivoNome]!;
                final isExpanded = _expandedPivos['${status}_$pivoNome'] ?? false;
                
                double areaTotalPivo = 0;
                int diasTotaisPivo = 0;
                for (var op in operacoes) {
                  areaTotalPivo += op.areaTotal ?? 0;
                  diasTotaisPivo += op.getDiasNecessarios();
                }
                
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _expandedPivos['${status}_$pivoNome'] = !isExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: isExpanded ? cor.withOpacity(0.05) : null),
                        child: Row(
                          children: [
                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pivoNome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text('${operacoes.length} operações • ${areaTotalPivo.toStringAsFixed(0)} ha${status != 'Concluído' && status != 'Dispensada' ? ' • $diasTotaisPivo dias' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(status, style: TextStyle(fontSize: 11, color: cor)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Column(
                        children: [
                          const Divider(height: 0, indent: 16),
                          ...operacoes.map((op) => _buildOperacaoTile(op, cor)),
                        ],
                      ),
                    if (index < pivosLista.length - 1) const Divider(height: 0, indent: 16),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOperacaoTile(OperacaoExecutada op, Color cor) {
    final diasNecessarios = op.getDiasNecessarios();
    final areaTotalComPassadas = op.getAreaTotalComPassadas();
    final tempoPrevisto = diasNecessarios == 1 ? '1 dia' : '$diasNecessarios dias';
    final dataInicioJanela = op.getDataInicioJanelaCalculada();
    final dataFimJanela = op.getDataFimJanelaCalculada();
    final dataInicio = op.dataInicioPrimeira;
    final dataConclusao = op.dataFimUltima;
    final isInconsistente = op.isRealmenteAtrasada;
    final mensagemAlerta = op.mensagemInconsistencia;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: op.corDestaqueInconsistencia,
        borderRadius: BorderRadius.circular(8),
        border: isInconsistente ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 90,
          decoration: BoxDecoration(
            color: isInconsistente ? Colors.red : cor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                op.operacaoNome ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  decoration: op.status == 'dispensada' ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isInconsistente)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ATRASADA',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (mensagemAlerta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  mensagemAlerta,
                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.square_foot, '${areaTotalComPassadas.toStringAsFixed(0)} ha (${op.numeroPassadas}x)', cor),
                _infoChip(Icons.speed, '${op.rendimentoHaDia?.toStringAsFixed(1)} ha/dia', cor),
                if (op.status != 'dispensada' && op.status != 'concluida') 
                  _infoChip(Icons.timer, tempoPrevisto, cor),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 11,
                    color: isInconsistente ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Janela: ${_formatarDataComAno(dataInicioJanela)} a ${_formatarDataComAno(dataFimJanela)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isInconsistente ? Colors.red : Colors.grey,
                      fontWeight: isInconsistente ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (op.status == 'em_andamento' && dataInicio != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.play_arrow, size: 12, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('Iniciado em: ${_formatarDataComAno(dataInicio)}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                ),
              ),
            if (op.status == 'concluida')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dataInicio != null)
                      Row(
                        children: [
                          Icon(Icons.play_arrow, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('Iniciado em: ${_formatarDataComAno(dataInicio)}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                    if (dataConclusao != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Concluído em: ${_formatarDataComAno(dataConclusao)}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (op.numeroPassadas != null && op.numeroPassadas! > 1 && op.status != 'concluida' && op.status != 'dispensada')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('⚠️ Múltiplas passadas necessárias', style: TextStyle(fontSize: 10, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
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
    final statuses = ['Concluído', 'Em andamento', 'Planejada', 'Atrasada', 'Dispensada'];

    for (var status in statuses) {
      final value = dados[status] ?? 0;
      if (value == 0) continue;

      final sweep = (value / total) * 2 * pi;
      final color = cores[status]!;
      final percent = (value / total) * 100;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, true, Paint()..color = color);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, true, Paint()..color = Colors.white.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);

      if (percent > 5) {
        final midAngle = startAngle + sweep / 2;
        final textRadius = radius * 0.65;
        final textOffset = Offset(center.dx + cos(midAngle) * textRadius, center.dy + sin(midAngle) * textRadius);
        final tp = TextPainter(text: TextSpan(text: "${percent.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)), textDirection: TextDirection.ltr);
        tp.layout();
        final textRect = Rect.fromCenter(center: textOffset, width: tp.width + 6, height: tp.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(textRect, const Radius.circular(4)), Paint()..color = Colors.black.withOpacity(0.5));
        tp.paint(canvas, Offset(textOffset.dx - tp.width / 2, textOffset.dy - tp.height / 2));
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}