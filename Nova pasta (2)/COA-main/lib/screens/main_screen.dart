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
  bool _isRefreshing = false;

  Future<void> _refreshAllData() async {
    setState(() => _isRefreshing = true);
    await widget.service.carregarOperacoes(forceReload: true);
    setState(() => _isRefreshing = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Dados recarregados com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    late final List<Widget> _telas;
    late final List<String> _titulosAbas;
    late final List<IconData> _iconesAbas;

    if (isAdmin) {
      _telas = [
        PainelScreen(service: widget.service),
        OperacoesScreen(service: widget.service),
        const PivosScreen(),
        const PlantioScreen(),
      ];
      _titulosAbas = ['Painel', 'Operações', 'Pivôs', 'Novo Plantio'];
      _iconesAbas = [Icons.dashboard, Icons.agriculture, Icons.grass, Icons.add_circle];
    } else {
      _telas = [
        PainelScreen(service: widget.service),
        OperacoesScreen(service: widget.service),
      ];
      _titulosAbas = ['Painel', 'Operações'];
      _iconesAbas = [Icons.dashboard, Icons.agriculture];
    }

    if (_selectedIndex >= _telas.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulosAbas[_selectedIndex]),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: 'Recarregar dados',
          ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                authProvider.currentEmail?.split('@').first ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
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
        children: _telas,
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
        items: List.generate(_telas.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_iconesAbas[index]),
            label: _titulosAbas[index],
          );
        }),
      ),
    );
  }
}