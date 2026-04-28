import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../models/operacao_executada.dart';

class AreaDetailScreen extends StatefulWidget {
  final AppService service;
  final String pivo;

  const AreaDetailScreen({
    super.key,
    required this.service,
    required this.pivo,
  });

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {

  String formatarData(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";
  }

  Color corStatus(String status) {
    switch (status) {
      case 'Atrasada':
        return Colors.red;
      case 'Em andamento':
        return Colors.blue;
      case 'Concluído':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar operações pelo nome do pivô
    final ops = widget.service.operacoes
        .where((o) => o.pivoNome == widget.pivo)
        .toList();

    if (ops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.pivo)),
        body: const Center(child: Text('Nenhuma operação encontrada')),
      );
    }

    final base = ops.first;

    return Scaffold(
      appBar: AppBar(title: Text(widget.pivo)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // INFO DA ÁREA
            Card(
              child: ListTile(
                title: Text('${base.areaTotal?.toStringAsFixed(0) ?? base.areaExecutada?.toStringAsFixed(0) ?? "0"} ha'),
                subtitle: Text(
                  'Plantio: ${formatarData(base.dataPlantio)}',
                ),
              ),
            ),

            const SizedBox(height: 10),

            // OPERAÇÕES
            Expanded(
              child: ListView(
                children: ops.map((op) {
                  String status = op.getStatusText();

                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 6,
                        height: 40,
                        color: op.getStatusColor(),
                      ),
                      title: Text(op.operacaoNome ?? ''),
                      subtitle: Text(
                        'Janela: ${formatarData(op.getDataInicioCalculada())} até ${formatarData(op.getDataTerminoCalculada())}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () {
                              widget.service.atualizarStatus(op, 'em_andamento');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () {
                              widget.service.atualizarStatus(op, 'concluida');
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}