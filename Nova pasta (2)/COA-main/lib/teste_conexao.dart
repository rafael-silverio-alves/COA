import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  
  final url = dotenv.env['SUPABASE_URL'];
  final key = dotenv.env['SUPABASE_ANON_KEY'];
  
  print('=== TESTE DE CONEXÃO SUPABASE ===');
  print('URL: $url');
  print('Key: ${key?.substring(0, 30)}...');
  
  if (url == null || key == null) {
    print('❌ ERRO: Credenciais não encontradas no .env');
    print('Verifique se o arquivo .env existe e tem as variáveis');
    return;
  }
  
  try {
    await Supabase.initialize(url: url, anonKey: key);
    print('✅ Supabase inicializado com sucesso!');
    
    final response = await Supabase.instance.client
        .from('operacoes_executadas')
        .select('*, pivos(*), operacoes_padrao(*)');
    
    print('✅ Total de operações: ${response.length}');
    
    if (response.isNotEmpty) {
      print('Primeira operação: ${response.first}');
    }
    
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text('Conectado! ${response.length} operações carregadas'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => print('Recarregando...'),
                child: const Text('Ver no console'),
              ),
            ],
          ),
        ),
      ),
    ));
  } catch (e) {
    print('❌ ERRO: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro: $e'),
            ],
          ),
        ),
      ),
    ));
  }
}