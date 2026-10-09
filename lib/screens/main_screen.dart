import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_service.dart';
import 'painel_screen.dart';
import 'operacoes_screen.dart';
import 'pivos_screen.dart';

class MainScreen extends StatefulWidget {
  final AppService service;

  const MainScreen({super.key, required this.service});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  // Paleta neutra
  static const Color _grafite = Color(0xFF1F2937);
  static const Color _grafiteClaro = Color(0xFF374151);
  static const Color _cinzaClaro = Color(0xFFE5E7EB);
  static const Color _cinzaMedio = Color(0xFF9CA3AF);
  static const Color _destaque = Color(0xFF2563EB);

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
      ];
      _titulosAbas = ['Painel', 'Operações', 'Pivôs'];
      _iconesAbas = [Icons.dashboard_outlined, Icons.agriculture_outlined, Icons.grass_outlined];
    } else {
      _telas = [
        PainelScreen(service: widget.service),
        OperacoesScreen(service: widget.service),
      ];
      _titulosAbas = ['Painel', 'Operações'];
      _iconesAbas = [Icons.dashboard_outlined, Icons.agriculture_outlined];
    }

    if (_selectedIndex >= _telas.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titulosAbas[_selectedIndex],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: _grafite,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: 'Recarregar dados',
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              isAdmin ? 'ADMIN' : 'USUÁRIO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Text(
                authProvider.currentEmail?.split('@').first ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD1D5DB),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _cinzaClaro, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _grafite,
          unselectedItemColor: _cinzaMedio,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: List.generate(_telas.length, (index) {
            return BottomNavigationBarItem(
              icon: Icon(_iconesAbas[index], size: 22),
              label: _titulosAbas[index],
            );
          }),
        ),
      ),
    );
  }
}