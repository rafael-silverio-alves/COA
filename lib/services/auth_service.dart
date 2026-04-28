import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('=== TENTANDO LOGIN ===');
      print('Email: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email.toLowerCase(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return {'success': false, 'error': 'Email ou senha incorretos'};
      }

      print('✅ Login bem-sucedido para: ${user.email}');
      print('User ID: ${user.id}');

      // Buscar o papel do usuário
      final roleResponse = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id);
      
      print('Role response: $roleResponse');
      
      String roleStr = 'user';
      if (roleResponse.isNotEmpty && roleResponse[0]['role'] != null) {
        roleStr = roleResponse[0]['role'].toString();
        print('Role encontrada no banco: "$roleStr"');
      } else {
        print('Nenhum role encontrado, criando registro com user...');
        await _supabase.from('user_roles').insert({
          'user_id': user.id,
          'role': 'user',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Converter para UserRole
      final userRole = UserRoleExtension.fromString(roleStr);
      print('UserRole convertido: $userRole');
      print('É admin? ${userRole == UserRole.admin}');

      return {
        'success': true,
        'user': user,
        'role': userRole,
        'email': user.email,
      };
    } catch (e) {
      print('❌ Erro no login: $e');
      return {'success': false, 'error': 'Email ou senha incorretos'};
    }
  }

  // Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Verificar se usuário está logado
  bool isLoggedIn() {
    return _supabase.auth.currentSession != null;
  }

  // Obter papel do usuário atual
  Future<UserRole> getCurrentUserRole() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      print('❌ Nenhuma sessão ativa');
      return UserRole.user;
    }
    
    print('=== GET CURRENT USER ROLE ===');
    print('User ID: ${session.user.id}');
    print('User Email: ${session.user.email}');
    
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', session.user.id);
      
      print('Resposta do banco: $response');
      
      if (response.isNotEmpty && response[0]['role'] != null) {
        final role = response[0]['role'].toString();
        print('Role encontrada: "$role"');
        final userRole = UserRoleExtension.fromString(role);
        print('UserRole retornado: $userRole');
        return userRole;
      }
      
      print('Nenhum registro encontrado, criando...');
      await _supabase.from('user_roles').insert({
        'user_id': session.user.id,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      return UserRole.user;
      
    } catch (e) {
      print('Erro ao buscar papel: $e');
      return UserRole.user;
    }
  }

  // Obter email do usuário atual
  String? getCurrentUserEmail() {
    return _supabase.auth.currentSession?.user.email;
  }

  // Listar todos os usuários
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final usersResponse = await _supabase.auth.admin.listUsers();
      final rolesResponse = await _supabase.from('user_roles').select('user_id, role');
      final rolesMap = {for (var r in rolesResponse) r['user_id']: r['role'] ?? 'user'};
      
      final List<Map<String, dynamic>> users = [];
      for (var user in usersResponse) {
        users.add({
          'user_id': user.id,
          'email': user.email,
          'role': rolesMap[user.id] ?? 'user',
          'created_at': user.createdAt?.toString(),
        });
      }
      
      return users;
    } catch (e) {
      print('Erro ao listar usuários: $e');
      return [];
    }
  }

  // Atualizar papel do usuário
  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      await _supabase.from('user_roles').upsert({
        'user_id': userId,
        'role': newRole,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      return true;
    } catch (e) {
      print('Erro ao atualizar papel: $e');
      return false;
    }
  }
}