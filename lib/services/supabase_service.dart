import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pivo.dart';
import '../models/cultura.dart';
import '../models/operacao_padrao.dart';
import '../models/operacao_executada.dart';
import '../models/safra.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _supabase;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    await dotenv.load();
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Credenciais do Supabase não encontradas');
    }
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    _supabase = Supabase.instance.client;
    _isInitialized = true;
    print('✅ Supabase inicializado com sucesso');
  }

  SupabaseClient get client {
    if (!_isInitialized) throw Exception('Supabase não inicializado');
    return _supabase;
  }

  // ========== AUTENTICAÇÃO ==========
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ========== PIVÔS ==========
  Future<List<Pivo>> getPivos() async {
    try {
      final response = await _supabase.from('pivos').select('*').order('nome');
      return response.map((data) => Pivo.fromMap(data)).toList();
    } catch (e) {
      print('Erro ao buscar pivôs: $e');
      return [];
    }
  }

  Future<void> addPivo(String nome, String? localizacao, double areaTotal) async {
    await _supabase.from('pivos').insert({
      'nome': nome,
      'localizacao': localizacao,
      'area_total': areaTotal,
    });
  }

  Future<void> deletePivo(String id) async {
    await _supabase.from('pivos').delete().eq('id', id);
  }

  // ========== CULTURAS ==========
  Future<List<Cultura>> getCulturas() async {
    try {
      final response = await _supabase.from('culturas').select('*').order('nome');
      return response.map((data) => Cultura.fromMap(data)).toList();
    } catch (e) {
      print('Erro ao buscar culturas: $e');
      return [];
    }
  }

  // ========== OPERAÇÕES PADRÃO ==========
  Future<List<OperacaoPadrao>> getOperacoesPadrao({String? culturaId}) async {
    try {
      var query = _supabase.from('operacoes_padrao').select('*');
      if (culturaId != null && culturaId.isNotEmpty) {
        query = query.eq('cultura_id', culturaId);
      }
      final response = await query.order('dias_antes_plantio');
      return response.map((data) => OperacaoPadrao.fromMap(data)).toList();
    } catch (e) {
      print('Erro ao buscar operações padrão: $e');
      return [];
    }
  }

  // ========== SAFRAS ==========
  Future<List<Safra>> getSafras({String? pivoId}) async {
    try {
      var query = _supabase.from('safras').select('*, pivos(*)');
      if (pivoId != null && pivoId.isNotEmpty) {
        query = query.eq('pivo_id', pivoId);
      }
      final response = await query.order('data_plantio', ascending: false);
      return response.map((data) => Safra.fromMap(data)).toList();
    } catch (e) {
      print('Erro ao buscar safras: $e');
      return [];
    }
  }

  // ========== OPERAÇÕES EXECUTADAS ==========
  Future<List<OperacaoExecutada>> getOperacoesExecutadas() async {
    try {
      print('📡 Buscando operações executadas...');
      
      final response = await _supabase
          .from('operacoes_executadas')
          .select('''
            *,
            safras!inner (
              *,
              pivos!inner (*)
            ),
            operacoes_padrao!inner (*)
          ''');
      
      print('📊 Encontradas ${response.length} operações');
      
      if (response.isEmpty) {
        print('⚠️ Nenhuma operação executada encontrada!');
        return [];
      }
      
      final operacoes = <OperacaoExecutada>[];
      
      for (var data in response) {
        try {
          final safraData = data['safras'];
          final pivoData = safraData?['pivos'];
          final opPadraoData = data['operacoes_padrao'];
          
          if (safraData == null) {
            print('⚠️ Safra não encontrada para operação ${data['id']}');
            continue;
          }
          
          if (opPadraoData == null) {
            print('⚠️ Operação padrão não encontrada para operação ${data['id']}');
            continue;
          }
          
          // DATA DE PLANTIO DA SAFRA
          final dataPlantio = safraData['data_plantio'] != null 
              ? DateTime.tryParse(safraData['data_plantio']) 
              : null;
          
          print('📅 === DEBUG OPERAÇÃO ===');
          print('Operação: ${opPadraoData['nome']}');
          print('Data plantio da safra: $dataPlantio');
          
          // VALORES DA JANELA
          final janelaInicioDias = opPadraoData['janela_inicio'] as int?;
          final janelaFimDias = opPadraoData['janela_fim'] as int?;
          final diasAntesPlantio = opPadraoData['dias_antes_plantio'] as int? ?? 0;
          
          print('janela_inicio: $janelaInicioDias');
          print('janela_fim: $janelaFimDias');
          print('dias_antes_plantio: $diasAntesPlantio');
          
          // CALCULAR DATAS DA JANELA
          DateTime? dataInicioJanela;
          DateTime? dataFimJanela;
          
          if (dataPlantio != null) {
            // Usar janela_inicio se disponível
            if (janelaInicioDias != null) {
              dataInicioJanela = dataPlantio.add(Duration(days: janelaInicioDias));
              print('Início calculado: $dataInicioJanela (${janelaInicioDias} dias após plantio)');
            } 
            // Fallback para dias_antes_plantio
            else if (diasAntesPlantio != null) {
              dataInicioJanela = dataPlantio.add(Duration(days: diasAntesPlantio));
              print('Início calculado (fallback): $dataInicioJanela (${diasAntesPlantio} dias após plantio)');
            }
            
            // Usar janela_fim se disponível
            if (janelaFimDias != null) {
              dataFimJanela = dataPlantio.add(Duration(days: janelaFimDias));
              print('Fim calculado: $dataFimJanela (${janelaFimDias} dias após plantio)');
            } 
            // Se não tem janela_fim, calcular padrão
            else if (dataInicioJanela != null) {
              dataFimJanela = dataInicioJanela.add(const Duration(days: 7));
              print('Fim calculado (padrão 7 dias): $dataFimJanela');
            }
          }
          
          // VALIDAR SE AS DATAS ESTÃO CORRETAS
          if (dataInicioJanela != null && dataFimJanela != null && dataInicioJanela.isAfter(dataFimJanela)) {
            print('⚠️ ATENÇÃO: Datas invertidas!');
            print('   Início: $dataInicioJanela');
            print('   Fim: $dataFimJanela');
            print('   Trocando as datas...');
            final temp = dataInicioJanela;
            dataInicioJanela = dataFimJanela;
            dataFimJanela = temp;
          }
          
          // CRIAR OBJETO OPERACAO
          final op = OperacaoExecutada(
            id: data['id'] ?? '',
            safraId: data['safra_id'] ?? '',
            operacaoPadraoId: data['operacao_padrao_id'] ?? '',
            dataInicioJanela: dataInicioJanela,
            dataFimJanela: dataFimJanela,
            dataInicioPrimeira: data['data_inicio_primeira'] != null 
                ? DateTime.tryParse(data['data_inicio_primeira']) 
                : null,
            dataFimUltima: data['data_fim_ultima'] != null 
                ? DateTime.tryParse(data['data_fim_ultima']) 
                : null,
            areaExecutada: (data['area_executada'] as num?)?.toDouble(),
            status: data['status'] ?? 'planejada',
            passadasConcluidas: data['passadas_concluidas'] ?? 0,
            passadasNecessarias: data['passadas_necessarias'] ?? 1,
            janelaInicioDias: janelaInicioDias,
            janelaFimDias: janelaFimDias,
          );
          
          // PREENCHER DADOS RELACIONADOS
          op.pivoNome = pivoData?['nome'] as String? ?? 'Sem Pivô';
          op.areaTotal = (pivoData?['area_total'] as num?)?.toDouble() ?? 0;
          op.dataPlantio = dataPlantio;
          
          op.operacaoNome = opPadraoData['nome'] as String? ?? 'Sem nome';
          op.rendimentoHaDia = (opPadraoData['rendimento_ha_dia'] as num?)?.toDouble() ?? 15.0;
          op.diasAntesPlantio = diasAntesPlantio;
          op.numeroPassadas = opPadraoData['numero_passadas'] as int? ?? 1;
          op.intervaloEntrePassadas = opPadraoData['intervalo_entre_passadas'] as int? ?? 0;
          
          operacoes.add(op);
          print('  ✅ ${op.operacaoNome} - ${op.pivoNome} (${op.getStatusText()})');
          print('  📅 Janela: ${_formatarData(op.dataInicioJanela)} a ${_formatarData(op.dataFimJanela)}');
          print('');
          
        } catch (e) {
          print('  ❌ Erro ao processar operação: $e');
        }
      }
      
      print('✅ Total de operações carregadas: ${operacoes.length}');
      return operacoes;
      
    } catch (e) {
      print('❌ Erro ao buscar operações executadas: $e');
      return [];
    }
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '---';
    return '${data.day}/${data.month}/${data.year}';
  }

  Future<void> updateOperacaoStatus(String id, String status, {DateTime? dataInicio, DateTime? dataFim}) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (dataInicio != null) {
        updates['data_inicio_primeira'] = dataInicio.toIso8601String();
      }
      if (dataFim != null) {
        updates['data_fim_ultima'] = dataFim.toIso8601String();
      }
      
      await _supabase.from('operacoes_executadas').update(updates).eq('id', id);
      print('✅ Status da operação $id atualizado para $status');
      
    } catch (e) {
      print('❌ Erro ao atualizar status: $e');
      rethrow;
    }
  }

  // ========== CADASTRAR PLANTIO ==========
  Future<void> cadastrarPlantio({
    required String pivoId,
    required String culturaId,
    required DateTime dataPlantio,
    String? anoSafra,
  }) async {
    try {
      final response = await _supabase.rpc(
        'gerar_operacoes_para_safra',
        params: {
          'p_pivo_id': pivoId,
          'p_cultura_id': culturaId,
          'p_data_plantio': dataPlantio.toIso8601String().split('T')[0],
          'p_ano_safra': anoSafra ?? '${dataPlantio.year}/${dataPlantio.year + 1}',
        },
      );
      
      print('✅ Plantio cadastrado com sucesso! Safra ID: $response');
    } catch (e) {
      print('❌ Erro ao cadastrar plantio: $e');
      rethrow;
    }
  }
}