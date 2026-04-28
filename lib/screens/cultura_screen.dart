import 'package:flutter/material.dart';
import '../services/app_service.dart';

class CulturaScreen extends StatefulWidget {
  final AppService service;

  const CulturaScreen({super.key, required this.service});

  @override
  State<CulturaScreen> createState() => _CulturaScreenState();
}

class _CulturaScreenState extends State<CulturaScreen> {
  final nome = TextEditingController();
  final cicloDias = TextEditingController();

  List<Map<String, dynamic>> operacoes = [];

  final opNome = TextEditingController();
  final opDias = TextEditingController();
  final opRendimento = TextEditingController();

  void addOperacao() {
    if (opNome.text.isEmpty || opDias.text.isEmpty) return;
    
    operacoes.add({
      'nome': opNome.text,
      'dias_antes_plantio': int.tryParse(opDias.text) ?? 0,
      'rendimento_ha_dia': double.tryParse(opRendimento.text) ?? 15.0,
    });

    opNome.clear();
    opDias.clear();
    opRendimento.clear();

    setState(() {});
  }

  void removerOperacao(int index) {
    operacoes.removeAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Cultura')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nome, 
              decoration: const InputDecoration(labelText: 'Nome da Cultura'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cicloDias, 
              decoration: const InputDecoration(labelText: 'Ciclo (dias)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Operações da Cultura', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: opNome, 
                    decoration: const InputDecoration(labelText: 'Operação', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: opDias, 
                    decoration: const InputDecoration(labelText: 'Dias antes', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: opRendimento, 
                    decoration: const InputDecoration(labelText: 'ha/dia', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: addOperacao, child: const Text('Adicionar Operação')),

            const SizedBox(height: 16),
            Expanded(
              child: operacoes.isEmpty
                  ? const Center(child: Text('Nenhuma operação adicionada'))
                  : ListView.builder(
                      itemCount: operacoes.length,
                      itemBuilder: (context, index) {
                        final op = operacoes[index];
                        return ListTile(
                          title: Text(op['nome']),
                          subtitle: Text('${op['dias_antes_plantio']} dias antes • ${op['rendimento_ha_dia']} ha/dia'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => removerOperacao(index),
                          ),
                        );
                      },
                    ),
            ),

            ElevatedButton(
              onPressed: () {
                // TODO: Implementar salvamento no Supabase
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Salvar Cultura'),
            )
          ],
        ),
      ),
    );
  }
}