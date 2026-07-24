import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';
import 'painel_screen.dart';
import 'operacoes_screen.dart';
import 'plantio_screen.dart';
import 'pivos_screen.dart';
import 'admin/users_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserRole initialRole;

  const HomeScreen({super.key, required this.initialRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppService service;
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  bool _isLoading = true;
  UserRole _userRole = UserRole.user;

  late final List<Widget> _allScreens;
  late final List<Widget> _userScreens;
  late final List<NavigationDestination> _allDestinations;
  late final List<NavigationDestination> _userDestinations;

  @override
  void initState() {
    super.initState();
    service = AppService();
    _userRole = widget.initialRole;
    
    _allScreens = [
      PainelScreen(service: service),
      OperacoesScreen(service: service),
      PlantioScreen(),
      PivosScreen(),
      UsersScreen(),
    ];
    
    _userScreens = [
      PainelScreen(service: service),
      OperacoesScreen(service: service),
    ];
    
    _allDestinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard), label: 'Painel'),
      NavigationDestination(icon: Icon(Icons.assignment), label: 'Operações'),
      NavigationDestination(icon: Icon(Icons.grass), label: 'Novo Plantio'),
      NavigationDestination(icon: Icon(Icons.location_on), label: 'Pivôs'),
      NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];
    
    _userDestinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard), label: 'Painel'),
      NavigationDestination(icon: Icon(Icons.assignment), label: 'Operações'),
    ];
    
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    await service.carregarOperacoes();
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = _userRole == UserRole.admin;
    final screens = isAdmin ? _allScreens : _userScreens;
    final destinations = isAdmin ? _allDestinations : _userDestinations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGA App'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _userRole.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _userRole.color),
            ),
            child: Text(
              _userRole.displayName,
              style: TextStyle(color: _userRole.color, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}