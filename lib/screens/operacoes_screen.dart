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
  Map<String, bool> _expandedPivos = {};

  List<OperacaoExecutada> get _operacoesFiltradas {
    return widget.service.operacoes.where((op) {
      if (_filtroPivo != 'Todos' && op.pivoNome != _filtroPivo) return false;
      if (_filtroStatus != 'Todos' && op.getStatusText() != _filtroStatus) return false;
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
        final dataA = a.dataInicioJanela ?? DateTime(3000);
        final dataB = b.dataInicioJanela ?? DateTime(3000);
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
    final pivos = ['Todos', ...widget.service.getPivosUnicos()];
    final statuses = ['Todos', 'Concluído', 'Em andamento', 'Planejada', 'Atrasada', 'Dispensada'];
    final totalOperacoes = _operacoesFiltradas.length;
    final totalPivos = _operacoesAgrupadas.length;

    return RefreshIndicator(
      onRefresh: () => widget.service.carregarOperacoes(),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filtroPivo,
                    decoration: const InputDecoration(labelText: 'Pivô', border: OutlineInputBorder()),
                    items: pivos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() { _filtroPivo = v!; _expandedPivos.clear(); }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filtroStatus,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() { _filtroStatus = v!; _expandedPivos.clear(); }),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${totalPivos} pivôs', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('$totalOperacoes operações', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ),
          ),
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
                    padding: const EdgeInsets.all(12),
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
                                          Text(pivoNome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                children: operacoes.map((op) => _buildOperacaoTile(op)).toList(),
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

  Widget _buildOperacaoTile(OperacaoExecutada op) {
    final cor = op.getStatusColor();
    final diasNecessarios = op.getDiasNecessarios();
    final tempoPrevisto = diasNecessarios == 1 ? '1 dia' : '$diasNecessarios dias';
    final areaTotalComPassadas = op.getAreaTotalComPassadas();
    final dataInicio = op.dataInicioPrimeira;
    final dataConclusao = op.dataFimUltima;
    final dataInicioJanela = op.dataInicioJanela;
    final dataFimJanela = op.dataFimJanela;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cor.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(width: 3, height: 80, color: cor),
        title: Text(
          op.operacaoNome ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: op.status == 'dispensada' ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.square_foot, '${areaTotalComPassadas.toStringAsFixed(0)} ha (${op.numeroPassadas}x)', cor),
                _infoChip(Icons.speed, '${op.rendimentoHaDia?.toStringAsFixed(1)} ha/dia', cor),
                if (op.status != 'dispensada' && op.status != 'concluida') _infoChip(Icons.timer, tempoPrevisto, cor),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.calendar_today, 'Janela: ${_formatarDataComAno(dataInicioJanela)} a ${_formatarDataComAno(dataFimJanela)}', cor),
              ],
            ),
            // Datas de início e conclusão
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.assignment, color: op.status == 'planejada' ? Colors.orange : Colors.grey),
              onPressed: () => _atualizarStatus(op, 'planejada'),
              tooltip: 'Planejada',
            ),
            IconButton(
              icon: Icon(Icons.play_arrow, color: op.status == 'em_andamento' ? Colors.blue : Colors.grey),
              onPressed: () => _atualizarStatus(op, 'em_andamento'),
              tooltip: 'Em andamento',
            ),
            IconButton(
              icon: Icon(Icons.warning, color: op.status == 'atrasada' ? Colors.red : Colors.grey),
              onPressed: () => _atualizarStatus(op, 'atrasada'),
              tooltip: 'Atrasada',
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: op.status == 'concluida' ? Colors.green : Colors.grey),
              onPressed: () => _atualizarStatus(op, 'concluida'),
              tooltip: 'Concluir',
            ),
            IconButton(
              icon: Icon(Icons.block, color: op.status == 'dispensada' ? Colors.grey : Colors.grey.shade400),
              onPressed: () => _atualizarStatus(op, 'dispensada'),
              tooltip: 'Dispensada',
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
          Text(label, style: TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }

  String _formatarDataComAno(DateTime? data) {
    if (data == null) return '---';
    return '${data.day}/${data.month}/${data.year}';
  }
}