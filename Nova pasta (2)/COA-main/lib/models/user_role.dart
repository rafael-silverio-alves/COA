import 'package:flutter/material.dart';

enum UserRole {
  admin,
  user;
}

extension UserRoleExtension on UserRole {
  static UserRole fromString(String role) {
    print('=== UserRoleExtension.fromString ===');
    print('String recebida: "$role"');
    
    final roleLower = role.toLowerCase().trim();
    print('String convertida: "$roleLower"');
    
    if (roleLower == 'admin') {
      print('✅ Retornando ADMIN');
      return UserRole.admin;
    } else if (roleLower == 'administrador') {
      print('✅ Retornando ADMIN (português)');
      return UserRole.admin;
    } else {
      print('❌ Retornando USER (padrão)');
      return UserRole.user;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.user:
        return 'Usuário';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.admin:
        return Colors.green;
      case UserRole.user:
        return Colors.blue;
    }
  }
}