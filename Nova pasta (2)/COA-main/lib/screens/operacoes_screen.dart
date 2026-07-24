import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../models/operacao_executada.dart';

class OperacoesScreen extends StatefulWidget {
  final AppService service;

  const OperacoesScreen({super.key, required this.service});

  @override
  State<OperacoesScreen> createState() => _OperacoesScreenState();
}

class _OperacoesScreenState extends State<OperacoesScreen> {
  String _filtroPivo = 'Todos';
  String _filtroStatus = 'Todos';
  String _filtroSafra = 'Todas';  // NOVO FILTRO DE SAFRA
  Map<String, bool> _expandedPivos = {};

  // Lista de safras disponíveis (ano_safra)
  List<String> get _safrasDisponiveis {
    final safras = <String>{};
    for (var op in widget.service.operacoes) {
      // Buscar o ano da safra a partir da data de plantio
      if (op.dataPlantio != null) {
        safras.add(op.dataPlantio!.year.toString());
      }
    }
    final lista = safras.toList();
    lista.sort((a, b) => b.compareTo(a)); // Mais recente primeiro
    return ['Todas', ...lista];
  }

  List<OperacaoExecutada> get _operacoesFiltradas {
    return widget.service.operacoes.where((op) {
      if (_filtroPivo != 'Todos' && op.pivoNome != _filtroPivo) return false;
      if (_filtroStatus != 'Todos' && op.getStatusText() != _filtroStatus) return false;
      // NOVO FILTRO: Filtrar por safra (ano)
      if (_filtroSafra != 'Todas' && op.dataPlantio != null) {
        final anoSafra = op.dataPlantio!.year.toString();
        if (anoSafra != _filtroSafra) return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<OperacaoExecutada>> get _operacoesAgrupadas {
    final map = <String, List<OperacaoExecutada>>{};
    for (var op in _operacoesFiltradas) {
      final pivo = op.pivoNome ?? 'Sem Pivô';
      map.putIfAbsent(pivo, () => []).add(op);
    }
    
    for (var pivo in map.keys) {
      map[pivo]!.sort((a, b) {
        final dataA = a.getDataInicioJanelaCalculada();
        final dataB = b.getDataInicioJanelaCalculada();
        return dataA.compareTo(dataB);
      });
    }
    
    return map;
  }

  List<String> get _pivosOrdenados {
    final lista = _operacoesAgrupadas.keys.toList();
    lista.sort();
    return lista;
  }

  Future<void> _atualizarStatus(OperacaoExecutada op, String novoStatus) async {
    await widget.service.atualizarStatus(op, novoStatus);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final pivos = ['Todos', ...widget.service.getPivosUnicos()];
    final statuses = ['Todos', 'Concluído', 'Em andamento', 'Planejada', 'Atrasada', 'Dispensada'];
    final safras = _safrasDisponiveis;
    final totalOperacoes = _operacoesFiltradas.length;
    final totalPivos = _operacoesAgrupadas.length;

    return RefreshIndicator(
      onRefresh: () => widget.service.carregarOperacoes(),
      child: Column(
        children: [
          // Filtros - layout responsivo
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: isSmallScreen
                ? Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _filtroPivo,
                        decoration: const InputDecoration(
                          labelText: 'Pivô',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: pivos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() { _filtroPivo = v!; _expandedPivos.clear(); }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _filtroStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() { _filtroStatus = v!; _expandedPivos.clear(); }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _filtroSafra,
                        decoration: const InputDecoration(
                          labelText: 'Safra',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: safras.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() { _filtroSafra = v!; _expandedPivos.clear(); }),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filtroPivo,
                          decoration: const InputDecoration(
                            labelText: 'Pivô',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: pivos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() { _filtroPivo = v!; _expandedPivos.clear(); }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filtroStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() { _filtroStatus = v!; _expandedPivos.clear(); }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filtroSafra,
                          decoration: const InputDecoration(
                            labelText: 'Safra',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: safras.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() { _filtroSafra = v!; _expandedPivos.clear(); }),
                        ),
                      ),
                    ],
                  ),
          ),
          // Resumo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$totalPivos pivôs', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('$totalOperacoes operações', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ),
          ),
          // Lista de operações
          Expanded(
            child: _pivosOrdenados.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Nenhuma operação encontrada', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    itemCount: _pivosOrdenados.length,
                    itemBuilder: (context, index) {
                      final pivoNome = _pivosOrdenados[index];
                      final operacoes = _operacoesAgrupadas[pivoNome]!;
                      final isExpanded = _expandedPivos[pivoNome] ?? false;
                      
                      int concluidas = 0, emAndamento = 0, atrasadas = 0, planejadas = 0, dispensadas = 0;
                      for (var op in operacoes) {
                        switch (op.status) {
                          case 'concluida': concluidas++; break;
                          case 'em_andamento': emAndamento++; break;
                          case 'atrasada': atrasadas++; break;
                          case 'dispensada': dispensadas++; break;
                          default: planejadas++;
                        }
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() { _expandedPivos[pivoNome] = !isExpanded; }),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(pivoNome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              if (concluidas > 0) _statusChip('✓ $concluidas', Colors.green),
                                              if (emAndamento > 0) _statusChip('▶ $emAndamento', Colors.blue),
                                              if (atrasadas > 0) _statusChip('⚠ $atrasadas', Colors.red),
                                              if (planejadas > 0) _statusChip('📋 $planejadas', Colors.orange),
                                              if (dispensadas > 0) _statusChip('⊘ $dispensadas', Colors.grey),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('${operacoes.length} ops', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Column(
                                children: operacoes.map((op) => _buildOperacaoTile(op, isSmallScreen)).toList(),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _buildOperacaoTile(OperacaoExecutada op, bool isSmallScreen) {
    final cor = op.getStatusColor();
    final diasNecessarios = op.getDiasNecessarios();
    final tempoPrevisto = diasNecessarios == 1 ? '1 dia' : '$diasNecessarios dias';
    final areaTotalComPassadas = op.getAreaTotalComPassadas();
    final dataInicio = op.dataInicioPrimeira;
    final dataConclusao = op.dataFimUltima;
    final dataInicioJanela = op.getDataInicioJanelaCalculada();
    final dataFimJanela = op.getDataFimJanelaCalculada();
    final dataPlantio = op.dataPlantio;
    final isInconsistente = op.isRealmenteAtrasada;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: op.corDestaqueInconsistencia,
        borderRadius: BorderRadius.circular(8),
        border: isInconsistente && op.status != 'atrasada' 
            ? Border.all(color: Colors.red, width: 1) 
            : null,
      ),
      child: ExpansionTile(
        leading: Container(width: 3, height: 40, color: cor),
        title: Text(
          op.operacaoNome ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: op.status == 'dispensada' ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: isSmallScreen ? null : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.square_foot, '${areaTotalComPassadas.toStringAsFixed(0)} ha (${op.numeroPassadas}x)', cor),
                _infoChip(Icons.speed, '${op.rendimentoHaDia?.toStringAsFixed(1)} ha/dia', cor),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInconsistente && op.status != 'atrasada')
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            op.mensagemInconsistencia ?? 'Operação fora da janela prevista',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                _detalheLinha('Área total', '${areaTotalComPassadas.toStringAsFixed(0)} ha (${op.numeroPassadas} passada(s))'),
                _detalheLinha('Rendimento', '${op.rendimentoHaDia?.toStringAsFixed(1)} ha/dia'),
                if (op.status != 'dispensada' && op.status != 'concluida')
                  _detalheLinha('Previsão', tempoPrevisto),
                _detalheLinha('Janela de execução', 
                  '${_formatarData(dataInicioJanela)} a ${_formatarData(dataFimJanela)}'),
                _detalheLinha('Data de plantio', dataPlantio != null ? _formatarData(dataPlantio) : '---'),
                if (op.status == 'em_andamento' && dataInicio != null)
                  _detalheLinha('Iniciado em', _formatarData(dataInicio)),
                if (op.status == 'concluida')
                  Column(
                    children: [
                      if (dataInicio != null)
                        _detalheLinha('Iniciado em', _formatarData(dataInicio)),
                      if (dataConclusao != null)
                        _detalheLinha('Concluído em', _formatarData(dataConclusao)),
                    ],
                  ),
                if (op.numeroPassadas != null && op.numeroPassadas! > 1 && op.status != 'concluida' && op.status != 'dispensada')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('⚠️ Múltiplas passadas necessárias', 
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _acaoBotao('Planejar', Icons.assignment, op.status == 'planejada' ? Colors.orange : Colors.grey, () => _atualizarStatus(op, 'planejada')),
                    _acaoBotao('Iniciar', Icons.play_arrow, op.status == 'em_andamento' ? Colors.blue : Colors.grey, () => _atualizarStatus(op, 'em_andamento')),
                    _acaoBotao('Atrasada', Icons.warning, op.status == 'atrasada' ? Colors.red : Colors.grey, () => _atualizarStatus(op, 'atrasada')),
                    _acaoBotao('Concluir', Icons.check_circle, op.status == 'concluida' ? Colors.green : Colors.grey, () => _atualizarStatus(op, 'concluida')),
                    _acaoBotao('Dispensar', Icons.block, op.status == 'dispensada' ? Colors.grey : Colors.grey.shade400, () => _atualizarStatus(op, 'dispensada')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalheLinha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acaoBotao(String label, IconData icon, Color cor, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: cor),
      label: Text(label, style: TextStyle(fontSize: 12, color: cor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: cor.withOpacity(0.1),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          Text(label, style: TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '---';
    return '${data.day}/${data.month}/${data.year}';
  }
}