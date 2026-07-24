import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/pivo.dart';

class PivosScreen extends StatefulWidget {
  const PivosScreen({super.key});

  @override
  State<PivosScreen> createState() => _PivosScreenState();
}

class _PivosScreenState extends State<PivosScreen> {
  final SupabaseService _supabase = SupabaseService();
  List<Pivo> _pivos = [];
  bool _isLoading = true;
  final _nomeController = TextEditingController();
  final _localizacaoController = TextEditingController();
  final _areaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarPivos();
  }

  Future<void> _carregarPivos() async {
    setState(() => _isLoading = true);
    await _supabase.init();
    _pivos = await _supabase.getPivos();
    setState(() => _isLoading = false);
  }

  Future<void> _adicionarPivo() async {
    if (_nomeController.text.isEmpty || _areaController.text.isEmpty) return;
    
    await _supabase.addPivo(
      _nomeController.text,
      _localizacaoController.text.isEmpty ? null : _localizacaoController.text,
      double.parse(_areaController.text),
    );
    
    _nomeController.clear();
    _localizacaoController.clear();
    _areaController.clear();
    await _carregarPivos();
    if (mounted) Navigator.pop(context);
  }

  void _mostrarDialogAdicionar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo Pivô'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _localizacaoController,
              decoration: const InputDecoration(labelText: 'Localização'),
            ),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(labelText: 'Área (ha)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: _adicionarPivo, child: const Text('Adicionar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pivôs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _mostrarDialogAdicionar,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pivos.isEmpty
              ? const Center(child: Text('Nenhum pivô cadastrado'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pivos.length,
                  itemBuilder: (context, index) {
                    final pivo = _pivos[index];
                    return Card(
                      child: ListTile(
                        title: Text(pivo.nome),
                        subtitle: Text('${pivo.areaTotal.toStringAsFixed(0)} ha'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _supabase.deletePivo(pivo.id);
                            await _carregarPivos();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}