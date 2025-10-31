import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

const _green = Color(0xFF669340);
const _dark  = Color(0xFF32384A);

class UserScreen extends StatelessWidget {
  const UserScreen({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.instance.me(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Não logado -> redireciona para a rota correta do login
        if (!snap.hasData || snap.data == null) {
          // agenda navegação fora do build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              // use o NOME da rota definido no app_router.dart
              context.goNamed('user_login'); 
              // (alternativa) context.go('/tabs/user/login');
            }
          });
          return const Scaffold(
            body: Center(child: Text('Redirecionando para login...')),
          );
        }

        final me = snap.data!;
        final nome = (me['first_name'] ?? me['name'] ?? me['email'] ?? 'Usuário').toString();
        final email = (me['email'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Minha conta', style: TextStyle(color: _dark)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Olá, $nome',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _green,
                            )),
                        Text(email, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),

              const _Item(icon: Icons.person_outline, title: 'Dados pessoais'),
              const _Item(icon: Icons.lock_reset, title: 'Trocar senha'),
              const _Item(icon: Icons.favorite_outline, title: 'Meus favoritos'),
              const _Item(icon: Icons.calendar_month, title: 'Minhas reservas'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await AuthService.instance.logout();
                    onChanged?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Você saiu da conta.')),
                      );
                      // Volta para a aba de usuário; o gate (UserEntryScreen) mandará para login
                      context.go('/tabs/user'); 
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Item({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: navegações específicas
      },
    );
  }
}
