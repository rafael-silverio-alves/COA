import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/pivo.dart';
import '../models/cultura.dart';

class PlantioScreen extends StatefulWidget {
  const PlantioScreen({super.key});

  @override
  State<PlantioScreen> createState() => _PlantioScreenState();
}

class _PlantioScreenState extends State<PlantioScreen> {
  final SupabaseService _supabase = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  
  List<Pivo> _pivos = [];
  List<Cultura> _culturas = [];
  String? _selectedPivoId;
  String? _selectedCulturaId;
  DateTime _selectedData = DateTime.now();
  String _anoSafra = '';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.init();
      _pivos = await _supabase.getPivos();
      _culturas = await _supabase.getCulturas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _cadastrarPlantio() async {
    if (_selectedPivoId == null || _selectedCulturaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um pivô e uma cultura'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      await _supabase.cadastrarPlantio(
        pivoId: _selectedPivoId!,
        culturaId: _selectedCulturaId!,
        dataPlantio: _selectedData,
        anoSafra: _anoSafra.isNotEmpty ? _anoSafra : '${_selectedData.year}/${_selectedData.year + 1}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantio cadastrado com sucesso!'), backgroundColor: Colors.green),
        );
        
        _formKey.currentState?.reset();
        setState(() {
          _selectedPivoId = null;
          _selectedCulturaId = null;
          _anoSafra = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.grass, size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Novo Plantio',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ao cadastrar um plantio, todas as operações serão geradas automaticamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedPivoId,
                      decoration: const InputDecoration(
                        labelText: 'Pivô',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: _pivos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))).toList(),
                      onChanged: (v) => setState(() => _selectedPivoId = v),
                      validator: (v) => v == null ? 'Selecione um pivô' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCulturaId,
                      decoration: const InputDecoration(
                        labelText: 'Cultura',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.eco),
                      ),
                      items: _culturas.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome))).toList(),
                      onChanged: (v) => setState(() => _selectedCulturaId = v),
                      validator: (v) => v == null ? 'Selecione uma cultura' : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Data do Plantio'),
                      subtitle: Text('${_selectedData.day}/${_selectedData.month}/${_selectedData.year}'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedData,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2027),
                        );
                        if (picked != null) setState(() => _selectedData = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Ano Safra (opcional)',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: 2025/2026',
                      ),
                      onChanged: (v) => _anoSafra = v,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _cadastrarPlantio,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('CADASTRAR PLANTIO', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}