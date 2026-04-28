import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_service.dart';
import 'painel_screen.dart';
import 'operacoes_screen.dart';
import 'pivos_screen.dart';
import 'plantio_screen.dart';

class MainScreen extends StatefulWidget {
  final AppService service;

  const MainScreen({super.key, required this.service});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Telas para USUÁRIO COMUM
  final List<Widget> _telasUsuario = [];
  final List<String> _titulosUsuario = [];
  final List<IconData> _iconesUsuario = [];

  // Telas para ADMINISTRADOR
  final List<Widget> _telasAdmin = [];
  final List<String> _titulosAdmin = [];
  final List<IconData> _iconesAdmin = [];

  @override
  void initState() {
    super.initState();
    
    // Configurar telas do USUÁRIO COMUM
    _telasUsuario.addAll([
      PainelScreen(service: widget.service),
      OperacoesScreen(service: widget.service),
    ]);
    _titulosUsuario.addAll(['Painel', 'Operações']);
    _iconesUsuario.addAll([Icons.dashboard, Icons.agriculture]);

    // Configurar telas do ADMINISTRADOR (todas as telas)
    _telasAdmin.addAll([
      PainelScreen(service: widget.service),
      OperacoesScreen(service: widget.service),
      const PivosScreen(),
      const PlantioScreen(),
    ]);
    _titulosAdmin.addAll(['Painel', 'Operações', 'Pivôs', 'Novo Plantio']);
    _iconesAdmin.addAll([
      Icons.dashboard,
      Icons.agriculture,
      Icons.grass,
      Icons.add_circle,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    // Escolher as listas baseado no papel do usuário
    final telas = isAdmin ? _telasAdmin : _telasUsuario;
    final titulos = isAdmin ? _titulosAdmin : _titulosUsuario;
    final icones = isAdmin ? _iconesAdmin : _iconesUsuario;

    // Garantir que o índice selecionado não ultrapasse o número de telas
    if (_selectedIndex >= telas.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_selectedIndex]),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Badge do papel do usuário
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAdmin ? 'ADMIN' : 'USUÁRIO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Email do usuário
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                authProvider.currentEmail?.split('@').first ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: telas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: List.generate(telas.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(icones[index]),
            label: titulos[index],
          );
        }),
      ),
    );
  }
}