// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/park_detail_screen.dart';
import '../screens/map_screen.dart';

// >>>>>> NOVOS imports do fluxo de usuário
import '../screens/user/user_entry_screen.dart';
import '../screens/user/login_screen.dart';
import '../screens/user/register_screen.dart';
import '../screens/user/register_success_screen.dart'; // 👈 ADICIONEI
import '../screens/favorites_screen.dart';
// <<<<<<

import '../screens/reservations/my_reservations_screen.dart';
import '../screens/reservations/reservations_screen.dart';
import '../screens/reservations/reservation_create_screen.dart';

import '../data/models/map_focus.dart';

abstract class AppRoutes {
  static const onboarding     = '/';
  static const home           = '/tabs/home';
  static const favorites      = '/tabs/favorites';
  static const map            = '/tabs/map';
  static const user           = '/tabs/user';

  // sub-rotas de Home
  static const homeReservas   = '/tabs/home/reservas';
  static const homeEventos    = '/tabs/home/eventos';
  static const homeInfo       = '/tabs/home/info';

  // sub-rotas de Usuário
  static const userReservas   = '/tabs/user/reservas';
  static const userLogin      = '/tabs/user/login';
  static const userRegister   = '/tabs/user/cadastro';
  static const userRegisterOk = '/user/register-success'; // 👈 NOVA ROTA

  static String homePark(String id) => '/tabs/home/park/$id';
  static String homeReservaNova(String spaceId) => '/tabs/home/reservas/new/$spaceId';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.onboarding,
  routes: [
    // ONBOARDING
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // ===== ROTA DE SUCESSO (fora das tabs, tela isolada) =====
    GoRoute(
      path: AppRoutes.userRegisterOk,
      name: 'user_register_success',
      builder: (context, state) => const RegisterSuccessScreen(),
    ),

    // TABS (IndexedStack)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _TabScaffold(navigationShell: navigationShell),
      branches: [
        // ===== HOME =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'reservas',
                  name: 'home_reservas',
                  builder: (context, state) => const ReservationsScreen(),
                  routes: [
                    GoRoute(
                      path: 'new/:spaceId',
                      name: 'home_reserva_nova',
                      builder: (context, state) => ReservationCreateScreen(
                        spaceId: state.pathParameters['spaceId']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'eventos',
                  name: 'home_eventos',
                  builder: (context, state) => const _StubPage(title: 'Eventos'),
                ),
                GoRoute(
                  path: 'info',
                  name: 'home_info',
                  builder: (context, state) => const _StubPage(title: 'Informações'),
                ),
                GoRoute(
                  path: 'park/:id',
                  name: 'home_park',
                  builder: (context, state) =>
                      ParkDetailScreen(parkId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),

        // ===== FAVORITOS =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.favorites,
              name: 'favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
          ],
        ),

        // ===== MAPA =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.map,
              name: 'map',
              builder: (context, state) {
                final focus = state.extra is MapFocus ? state.extra as MapFocus : null;
                return MapScreen(target: focus);
              },
            ),
          ],
        ),

        // ===== USUÁRIO =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.user,
              name: 'user',
              builder: (context, state) => const UserEntryScreen(),
              routes: [
                GoRoute(
                  path: 'login',
                  name: 'user_login',
                  builder: (context, state) => const LoginScreen(),
                ),
                GoRoute(
                  path: 'cadastro',
                  name: 'user_register',
                  builder: (context, state) => const RegisterScreen(),
                ),
                GoRoute(
                  path: 'reservas',
                  name: 'user_reservas',
                  builder: (context, state) => const MyReservationsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _TabScaffold extends StatefulWidget {
  const _TabScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<_TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends State<_TabScaffold> {
  static const Color green = Color(0xFF669340);
  static const Color darkGray = Color(0xFF32384A);
  static const Color border = Color(0xFFE6E6E6);

  int get _currentIndex => widget.navigationShell.currentIndex;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == _currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 68,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            indicatorColor: green.withOpacity(.16),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              final selected = states.contains(MaterialState.selected);
              return IconThemeData(color: selected ? green : darkGray, size: selected ? 26 : 24);
            }),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              final selected = states.contains(MaterialState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? green : darkGray,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined),   label: 'Home'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Favoritos'),
              NavigationDestination(icon: Icon(Icons.map_outlined),    label: 'Mapa'),
              NavigationDestination(icon: Icon(Icons.person_outline),  label: 'Usuário'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StubPage extends StatelessWidget {
  const _StubPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 22))),
    );
  }
}
