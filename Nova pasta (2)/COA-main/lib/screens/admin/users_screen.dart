import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _authService.getAllUsers();
    setState(() => _isLoading = false);
  }

  String _getRoleDisplay(String role) {
    switch (role.toLowerCase()) {
      case 'administrador':
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuário';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'administrador':
      case 'admin':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Future<void> _toggleAdmin(String userId, String currentRole) async {
    final newRole = currentRole.toLowerCase() == 'administrador' ? 'usuário' : 'administrador';
    
    await _supabase
        .from('user_roles')
        .update({'papel': newRole})
        .eq('user_id', userId);
    
    _loadUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newRole == 'administrador' ? 'Admin adicionado!' : 'Admin removido!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Nenhum usuário encontrado'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final role = user['papel'] ?? 'usuário';
                    final isAdmin = role.toLowerCase() == 'administrador';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getRoleColor(role).withOpacity(0.1),
                                  child: Icon(Icons.person, color: _getRoleColor(role)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['email'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Criado em: ${_formatDate(user['created_at'])}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getRoleDisplay(role),
                                    style: TextStyle(color: _getRoleColor(role), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _toggleAdmin(user['user_id'], role),
                                  icon: Icon(isAdmin ? Icons.person : Icons.admin_panel_settings, size: 18),
                                  label: Text(isAdmin ? 'Remover Admin' : 'Tornar Admin'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAdmin ? Colors.orange : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Data desconhecida';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}