import 'package:flutter/material.dart';
import '../models/operacao_executada.dart';
import 'supabase_service.dart';

class AppService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  
  List<OperacaoExecutada> _operacoes = [];
  List<OperacaoExecutada> get operacoes => _operacoes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> carregarOperacoes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('🔄 Carregando operações do Supabase...');
      
      await _supabase.init();
      
      _operacoes = await _supabase.getOperacoesExecutadas();
      
      print('✅ Carregadas ${_operacoes.length} operações');
      
      if (_operacoes.isEmpty) {
        print('⚠️ NENHUMA operação encontrada!');
      } else {
        print('📊 RESUMO:');
        final resumo = getResumo();
        resumo.forEach((status, count) {
          if (count > 0) print('  - $status: $count');
        });
      }
      
    } catch (e) {
      _error = e.toString();
      print('❌ Erro ao carregar: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> atualizarStatus(OperacaoExecutada op, String novoStatus) async {
    try {
      final index = _operacoes.indexWhere((o) => o.id == op.id);
      if (index != -1) {
        _operacoes[index].atualizarStatus(novoStatus);
        await _supabase.updateOperacaoStatus(
          op.id,
          _operacoes[index].status,
          dataInicio: _operacoes[index].dataInicioPrimeira,
          dataFim: _operacoes[index].dataFimUltima,
        );
        notifyListeners();
        print('✅ Status atualizado para: $novoStatus');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Erro ao atualizar status: $e');
      notifyListeners();
    }
  }

  Map<String, int> getResumo() {
    final Map<String, int> resumo = {
      'Concluído': 0,
      'Em andamento': 0,
      'Planejada': 0,
      'Atrasada': 0,
      'Dispensada': 0,
    };
    
    for (var op in _operacoes) {
      final status = op.getStatusText();
      resumo[status] = (resumo[status] ?? 0) + 1;
    }
    
    return resumo;
  }

  List<OperacaoExecutada> getOperacoesPorStatus(String status) {
    return _operacoes.where((op) => op.getStatusText() == status).toList();
  }

  List<String> getPivosUnicos() {
    final pivos = <String>{};
    for (var op in _operacoes) {
      if (op.pivoNome != null && op.pivoNome!.isNotEmpty) {
        pivos.add(op.pivoNome!);
      }
    }
    final lista = pivos.toList();
    lista.sort();
    return lista;
  }

  List<String> getOperacoesUnicas() {
    final operacoes = <String>{};
    for (var op in _operacoes) {
      if (op.operacaoNome != null && op.operacaoNome!.isNotEmpty) {
        operacoes.add(op.operacaoNome!);
      }
    }
    final lista = operacoes.toList();
    lista.sort();
    return lista;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}