import 'package:flutter/material.dart';
import '../services/app_service.dart';
import 'area_detail_screen.dart';

class AreasScreen extends StatefulWidget {
  final AppService service;

  const AreasScreen({super.key, required this.service});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  String busca = '';

  @override
  Widget build(BuildContext context) {
    // Agrupar operações por pivô usando pivoNome
    final Map<String, dynamic> areasMap = {};
    
    for (var op in widget.service.operacoes) {
      final pivoNome = op.pivoNome ?? 'Sem Pivô';
      if (!areasMap.containsKey(pivoNome)) {
        areasMap[pivoNome] = op;
      }
    }

    final areas = areasMap.values.toList();
    
    // Filtrar por busca
    final areasFiltradas = busca.isEmpty
        ? areas
        : areas.where((area) {
            final pivoNome = area.pivoNome ?? '';
            return pivoNome.toLowerCase().contains(busca.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Áreas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar pivô...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: busca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            busca = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  busca = value;
                });
              },
            ),
          ),
        ),
      ),
      body: areasFiltradas.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma área encontrada',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: areasFiltradas.length,
              itemBuilder: (context, index) {
                final area = areasFiltradas[index];
                final pivoNome = area.pivoNome ?? 'Sem Pivô';
                final areaTotal = area.areaTotal ?? 0;
                final dataPlantio = area.dataPlantio;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AreaDetailScreen(
                            service: widget.service,
                            pivo: pivoNome,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pivoNome,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.square_foot,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${areaTotal.toStringAsFixed(0)} hectares',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Plantio: ${_formatarData(dataPlantio)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/"
        "${data.month.toString().padLeft(2, '0')}/"
        "${data.year}";
  }
}