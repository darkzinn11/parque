// lib/screens/user/user_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'user_screen.dart';
import 'login_screen.dart';

class UserEntryScreen extends StatelessWidget {
  const UserEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: AuthService.instance,
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.currentUser == null) {
            return const LoginScreen();
          } else {
            return UserScreen(
              onChanged: () {
                auth.logout(); // ao sair volta pro login
              },
            );
          }
        },
      ),
    );
  }
}
