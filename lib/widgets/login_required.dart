import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../routes/app_router.dart';

final _auth = AuthService.instance;

/// Use assim nas ações protegidas:
/// final ok = await requireLogin(context, featureName: 'favoritar');
/// if (!ok) return; // usuário foi levado à aba Usuário para logar
Future<bool> requireLogin(BuildContext context, {String featureName = 'esta ação'}) async {
  final logged = await _auth.isLogged();
  if (logged) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Login necessário'),
      content: Text('Você precisa entrar para usar $featureName.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Agora não')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Fazer login')),
      ],
    ),
  );

  if (go == true && context.mounted) {
    // Seleciona a aba Usuário do seu StatefulShellRoute
    context.go(AppRoutes.user);
  }
  return false;
}
