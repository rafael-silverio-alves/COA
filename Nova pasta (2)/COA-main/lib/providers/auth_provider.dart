import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserRole? _currentRole;
  String? _currentEmail;
  bool _isLoading = true;

  UserRole? get currentRole => _currentRole;
  String? get currentEmail => _currentEmail;
  bool get isLoading => _isLoading;
  bool get isAdmin {
    final result = _currentRole == UserRole.admin;
    print('🔍 AuthProvider.isAdmin: $result (role: $_currentRole)');
    return result;
  }

  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();
    
    _currentRole = await _authService.getCurrentUserRole();
    _currentEmail = _authService.getCurrentUserEmail();
    
    print('📱 loadUserData - Role: $_currentRole, isAdmin: ${_currentRole == UserRole.admin}');
    
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _authService.login(email, password);
    
    if (result['success'] == true) {
      _currentRole = result['role'];
      _currentEmail = result['email'];
      print('🔐 Login - Role: $_currentRole, isAdmin: ${_currentRole == UserRole.admin}');
      notifyListeners();
    }
    
    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentRole = null;
    _currentEmail = null;
    notifyListeners();
  }
}