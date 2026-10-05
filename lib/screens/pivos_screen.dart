import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/pivo.dart';
import '../models/safra.dart';
import '../models/cultura.dart';

class PivosScreen extends StatefulWidget {
  const PivosScreen({super.key});

  @override
  State<PivosScreen> createState() => _PivosScreenState();
}

class _PivosScreenState extends State<PivosScreen> {
  final SupabaseService _supabase = SupabaseService();
  List<Pivo> _pivos = [];
  List<Cultura> _culturas = [];
  final Map<String, List<Safra>> _safrasPorPivo = {};
  bool _isLoading = true;

  // Busca
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _carregarPivos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarPivos() async {
    setState(() => _isLoading = true);
    await _supabase.init();

    _pivos = await _supabase.getPivos();
    _culturas = await _supabase.getCulturas();

    _safrasPorPivo.clear();
    for (final pivo in _pivos) {
      final safras = await _supabase.getSafrasDoPivo(pivo.id);
      _safrasPorPivo[pivo.id] = safras;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Pivôs filtrados pela busca (nome, localização ou ano safra).
  List<Pivo> get _pivosFiltrados {
    if (_searchQuery.trim().isEmpty) return _pivos;

    final query = _searchQuery.trim().toLowerCase();

    return _pivos.where((pivo) {
      // Nome
      if (pivo.nome.toLowerCase().contains(query)) return true;

      // Localização
      final loc = pivo.localizacao?.toLowerCase() ?? '';
      if (loc.contains(query)) return true;

      // Ano safra (das safras do pivô)
      final safras = _safrasPorPivo[pivo.id] ?? [];
      for (final safra in safras) {
        final ano = safra.anoSafra?.toLowerCase() ?? '';
        if (ano.contains(query)) return true;
      }

      return false;
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  /// Diálogo unificado: cria pivô + primeira safra.
  Future<void> _mostrarDialogNovoPivoComSafra() async {
    if (_culturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma cultura cadastrada. Cadastre uma cultura antes de criar um pivô.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nomeController = TextEditingController();
    final localizacaoController = TextEditingController();
    final areaController = TextEditingController();

    String? culturaSelecionadaId = _culturas.first.id;
    DateTime dataSelecionada = DateTime.now();
    final anoController = TextEditingController(
      text: '${DateTime.now().year}/${DateTime.now().year + 1}',
    );

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Novo Pivô'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados do pivô',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: localizacaoController,
                      decoration: const InputDecoration(
                        labelText: 'Localização (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaController,
                      decoration: const InputDecoration(
                        labelText: 'Área total (ha)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const Divider(height: 32),

                    const Text(
                      'Primeira safra',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: culturaSelecionadaId,
                      decoration: const InputDecoration(
                        labelText: 'Cultura',
                        border: OutlineInputBorder(),
                      ),
                      items: _culturas
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => culturaSelecionadaId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dataSelecionada,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Data de plantio',
                        );
                        if (picked != null) {
                          setDialogState(() => dataSelecionada = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de plantio',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${dataSelecionada.day.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.month.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: anoController,
                      decoration: const InputDecoration(
                        labelText: 'Ano safra',
                        hintText: 'Ex: 2024/2025',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Cadastrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != true) {
      nomeController.dispose();
      localizacaoController.dispose();
      areaController.dispose();
      anoController.dispose();
      return;
    }

    final nome = nomeController.text.trim();
    final localizacao = localizacaoController.text.trim();
    final areaTexto = areaController.text.trim().replaceAll(',', '.');

    if (nome.isEmpty || areaTexto.isEmpty || culturaSelecionadaId == null) {
      nomeController.dispose();
      localizacaoController.dispose();
      areaController.dispose();
      anoController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha nome, área e cultura.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final area = double.tryParse(areaTexto);
    if (area == null || area <= 0) {
      nomeController.dispose();
      localizacaoController.dispose();
      areaController.dispose();
      anoController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Área inválida.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final anoSafra = anoController.text.trim().isEmpty
        ? null
        : anoController.text.trim();

    nomeController.dispose();
    localizacaoController.dispose();
    areaController.dispose();
    anoController.dispose();

    try {
      setState(() => _isLoading = true);

      final pivoId = await _supabase.addPivoRetornandoId(
        nome: nome,
        localizacao: localizacao.isEmpty ? null : localizacao,
        areaTotal: area,
      );

      await _supabase.cadastrarPlantio(
        pivoId: pivoId,
        culturaId: culturaSelecionadaId!,
        dataPlantio: dataSelecionada,
        anoSafra: anoSafra,
      );

      await _carregarPivos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pivô e safra cadastrados com sucesso'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao cadastrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Diálogo de cadastro de safra adicional para um pivô existente.
  Future<void> _mostrarDialogNovaSafra(Pivo pivo) async {
    if (_culturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Nenhuma cultura cadastrada. Cadastre uma cultura antes.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? culturaSelecionadaId = _culturas.first.id;
    DateTime dataSelecionada = DateTime.now();
    final anoController = TextEditingController(
      text: '${DateTime.now().year}/${DateTime.now().year + 1}',
    );

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Nova Safra — ${pivo.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: culturaSelecionadaId,
                      decoration: const InputDecoration(
                        labelText: 'Cultura',
                        border: OutlineInputBorder(),
                      ),
                      items: _culturas
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => culturaSelecionadaId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dataSelecionada,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Data de plantio',
                        );
                        if (picked != null) {
                          setDialogState(() => dataSelecionada = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de plantio',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${dataSelecionada.day.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.month.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: anoController,
                      decoration: const InputDecoration(
                        labelText: 'Ano safra',
                        hintText: 'Ex: 2024/2025',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Cadastrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != true) {
      anoController.dispose();
      return;
    }

    if (culturaSelecionadaId == null) {
      anoController.dispose();
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _supabase.cadastrarPlantio(
        pivoId: pivo.id,
        culturaId: culturaSelecionadaId!,
        dataPlantio: dataSelecionada,
        anoSafra: anoController.text.trim().isEmpty
            ? null
            : anoController.text.trim(),
      );

      await _carregarPivos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Safra cadastrada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao cadastrar safra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      anoController.dispose();
    }
  }

  /// Diálogo de edição de safra existente.
  Future<void> _editarSafra(Safra safra) async {
    DateTime dataSelecionada = safra.dataPlantio;
    final anoController = TextEditingController(text: safra.anoSafra ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Safra'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dataSelecionada,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Data de plantio',
                        );
                        if (picked != null) {
                          setDialogState(() => dataSelecionada = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de plantio',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${dataSelecionada.day.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.month.toString().padLeft(2, '0')}/'
                          '${dataSelecionada.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: anoController,
                      decoration: const InputDecoration(
                        labelText: 'Ano safra',
                        hintText: 'Ex: 2024/2025',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != true) {
      anoController.dispose();
      return;
    }

    try {
      await _supabase.updateSafra(
        safraId: safra.id,
        dataPlantio: dataSelecionada,
        anoSafra: anoController.text.trim().isEmpty
            ? null
            : anoController.text.trim(),
      );
      await _carregarPivos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Safra atualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      anoController.dispose();
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final pivosFiltrados = _pivosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Buscar pivô, localização ou safra...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Pivôs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Fechar busca' : 'Buscar',
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Novo pivô',
              onPressed: _mostrarDialogNovoPivoComSafra,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pivos.isEmpty
              ? const Center(child: Text('Nenhum pivô cadastrado'))
              : pivosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum pivô encontrado',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pivosFiltrados.length,
                      itemBuilder: (context, index) {
                        final pivo = pivosFiltrados[index];
                        final safras = _safrasPorPivo[pivo.id] ?? [];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pivo.nome,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${pivo.areaTotal.toStringAsFixed(0)} ha'
                                            '${pivo.localizacao != null && pivo.localizacao!.isNotEmpty ? ' • ${pivo.localizacao}' : ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Excluir pivô',
                                      onPressed: () async {
                                        final confirmar =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title:
                                                const Text('Excluir pivô'),
                                            content: Text(
                                              'Excluir "${pivo.nome}"? As safras associadas também serão removidas.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child:
                                                    const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style:
                                                    TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child:
                                                    const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmar == true) {
                                          await _supabase.deletePivo(pivo.id);
                                          await _carregarPivos();
                                        }
                                      },
                                    ),
                                  ],
                                ),

                                const Divider(height: 20),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.agriculture,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Safras (${safras.length})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _mostrarDialogNovaSafra(pivo),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text(
                                        'Nova safra',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.green[700],
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                if (safras.isEmpty)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Nenhuma safra cadastrada',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else
                                  ...safras.map((safra) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  safra.anoSafra?.isNotEmpty ==
                                                          true
                                                      ? 'Safra ${safra.anoSafra}'
                                                      : 'Safra sem ano',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Plantio: ${_formatarData(safra.dataPlantio)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                if (safra.culturaNome != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: Text(
                                                      'Cultura: ${safra.culturaNome}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                              size: 18,
                                            ),
                                            tooltip: 'Editar safra',
                                            onPressed: () =>
                                                _editarSafra(safra),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}