import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Splash
import '../screens/splash_screen.dart';

// Onboarding + Tabs
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';

// >>>>>> Fluxo de usuário
import '../screens/user/user_entry_screen.dart';
import '../screens/user/login_screen.dart';
import '../screens/user/register_screen.dart';
import '../screens/user/register_success_screen.dart';
import '../screens/user/preferencias_screen.dart';
// <<<<<<

// Telas de funcionalidades
import '../screens/favorites_screen.dart';
import '../screens/atividade_screen.dart'; // ✅ Tela de Atividade (Strava-like)

// Park detail
import '../screens/park_detail_screen.dart';
import '../data/models/map_focus.dart';

// ===== Eventos
import '../screens/eventos_list_screen.dart';
import '../screens/evento_detail_screen.dart';
// ===== Informações
import '../screens/informacoes_screen.dart';
import '../screens/denuncie_screen.dart';

import '../screens/run_tracking_screen.dart'; // ✅ NOVO

// ===== Reservas de Espaços
import '../screens/reservations/park_selection_screen.dart';
import '../screens/reservations/spaces_catalog_screen.dart';
import '../screens/reservations/space_detail_screen.dart';
import '../screens/reservations/booking_calendar_screen.dart';
import '../screens/reservations/reservation_form_screen.dart';
import '../screens/reservations/my_reservations_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/user/verificar_codigo_screen.dart';
import '../screens/user/nova_senha_screen.dart';
import '../data/models/reservation.dart';

abstract class AppRoutes {
  // raízes
  static const splash         = '/';              // ✅ Rota inicial (Splash)
  static const onboarding     = '/onboarding';    // ✅ Onboarding separado
  
  static const home           = '/tabs/home';
  static const atividade      = '/tabs/atividade';        // ✅ Nova aba
  static const map            = '/tabs/map';
  static const user           = '/tabs/user';

  // sub-rotas de Atividade
  static const atividadeTracking = '/tabs/atividade/tracking'; // ✅ NOVO

  // sub-rotas de Home
  static const homeEventos    = '/tabs/home/eventos';
  static const homeInfo       = '/tabs/home/info';
  static const homeFavorites  = '/tabs/home/favorites'; // ✅ Favoritos via Home
  static const homeDenuncie   = '/tabs/home/denuncie';
  static const homeNotificacoes    = '/tabs/home/notificacoes';
  static const homeReservas        = '/tabs/home/reservas'; // seleção de parque
  static const homeReservasCatalog = '/tabs/home/reservas/parque/:parkId';
  static const homeReservasDetail  = '/tabs/home/reservas/espaco/:id';
  static const homeReservasBooking = '/tabs/home/reservas/espaco/:id/agendar';
  static const homeReservasForm    = '/tabs/home/reservas/espaco/:id/formulario';

  // sub-rotas de Usuário (reservas)
  static const userReservations    = '/tabs/user/minhas-reservas';
  
  static String homePark(String id) => '/tabs/home/park/$id';

  // sub-rotas de Usuário
  static const userLogin      = '/tabs/user/login';
  static const userRegister   = '/tabs/user/cadastro';
  static const userPrefs      = '/tabs/user/preferencias';

  // telas soltas (fora das tabs)
  static const userRegisterOk = '/user/register-success';

  // atalho global para abrir detalhes
  static String parkDetail(String id)   => '/parks/$id';
  static String eventoDetail(String id) => '/eventos/$id';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash, // ✅ Começa pelo Splash
  routes: [
    // ========= SPLASH SCREEN (TELA INICIAL) =========
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // ========= ONBOARDING =========
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // ========= TELA SOLTA: SUCESSO DE CADASTRO =========
    GoRoute(
      path: AppRoutes.userRegisterOk,
      name: 'user_register_success',
      builder: (context, state) => const RegisterSuccessScreen(),
    ),

    // ========= RECUPERAÇÃO DE SENHA =========
    GoRoute(
      path: '/verificar-codigo',
      name: 'verificar_codigo',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return VerificarCodigoScreen(email: extra['email']?.toString() ?? '');
      },
    ),
    GoRoute(
      path: '/nova-senha',
      name: 'nova_senha',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return NovaSenhaScreen(
          email: extra['email']?.toString() ?? '',
          code: extra['code']?.toString() ?? '',
        );
      },
    ),

    // ========= TELA SOLTA: PARK DETAIL (GLOBAL) =========
    GoRoute(
      path: '/parks/:id',
      name: 'park_detail',
      pageBuilder: (context, state) => _sharedAxisPage(
        key: state.pageKey,
        child: ParkDetailScreen(parkId: state.pathParameters['id']!),
      ),
    ),

    // ========= TELA SOLTA: EVENTO DETAIL (GLOBAL) =========
    GoRoute(
      path: '/eventos/:id',
      name: 'evento_detail',
      pageBuilder: (context, state) => _sharedAxisPage(
        key: state.pageKey,
        child: EventoDetailScreen(eventId: state.pathParameters['id']!),
      ),
    ),

    // ========= TABS =========
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _TabScaffold(navigationShell: navigationShell),
      branches: [
        // ===== 1. HOME =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'park/:id',
                  name: 'home_park_detail',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: ParkDetailScreen(parkId: state.pathParameters['id']!),
                  ),
                ),
                GoRoute(
                  path: 'eventos',
                  name: 'home_eventos',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const EventosListScreen(),
                  ),
                ),
                GoRoute(
                  path: 'info',
                  name: 'home_info',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const InformacoesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'favorites',
                  name: 'home_favorites',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const FavoritesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'denuncie',
                  name: 'home_denuncie',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const DenuncieScreen(),
                  ),
                ),
                GoRoute(
                  path: 'notificacoes',
                  name: 'home_notificacoes',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const NotificationsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'reservas',
                  name: 'home_reservas_parks',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const ParkSelectionScreen(),
                  ),
                ),
                GoRoute(
                  path: 'reservas/parque/:parkId',
                  name: 'home_reservas_catalog',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: SpacesCatalogScreen(parkId: int.parse(state.pathParameters['parkId']!)),
                  ),
                ),
                GoRoute(
                  path: 'reservas/espaco/:id',
                  name: 'home_reservas_detail',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: SpaceDetailScreen(spaceId: int.parse(state.pathParameters['id']!)),
                  ),
                ),
                GoRoute(
                  path: 'reservas/espaco/:id/agendar',
                  name: 'home_reservas_booking',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: BookingCalendarScreen(spaceId: int.parse(state.pathParameters['id']!)),
                  ),
                ),
                GoRoute(
                  path: 'reservas/espaco/:id/formulario',
                  name: 'home_reservas_form',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: ReservationFormScreen(
                      bookingData: state.extra as Map<String, dynamic>?,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ===== 2. ATIVIDADE (NOVA ABA) =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.atividade,
              name: 'atividade',
              builder: (context, state) => const AtividadeScreen(),
              routes: [
                // ✅ Tela de gravação dentro da pilha da aba Atividade
                GoRoute(
                  path: 'tracking',
                  name: 'atividade_tracking',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: RunTrackingScreen(
                      activityType: (state.extra as String?) ?? 'corrida',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ===== 3. MAPA =====
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.map,
              name: 'map',
              builder: (context, state) {
                final focus =
                    state.extra is MapFocus ? state.extra as MapFocus : null;
                return MapScreen(target: focus);
              },
            ),
          ],
        ),

        // ===== 4. USUÁRIO =====
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
                  path: 'preferencias',
                  name: 'user_preferences',
                  builder: (context, state) => const PreferenciasScreen(),
                ),
                GoRoute(
                  path: 'minhas-reservas',
                  name: 'user_reservations',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: const MyReservationsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'minhas-reservas/:id/editar',
                  name: 'user_reservation_edit',
                  pageBuilder: (context, state) => _sharedAxisPage(
                    key: state.pageKey,
                    child: ReservationFormScreen(
                      reservation: state.extra as Reservation?,
                    ),
                  ),
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
  static const Color border = Color(0xFFE6E6E6);

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined,    label: 'Home'),
    _TabItem(icon: Icons.directions_run,   label: 'Atividade'),
    _TabItem(icon: Icons.map_outlined,     label: 'Mapa'),
    _TabItem(icon: Icons.person_outline,   label: 'Usuário'),
  ];

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: _SlidingTabBar(
              selectedIndex: _currentIndex,
              tabs: _tabs,
              color: green,
              onTap: _onTap,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dados de cada aba ─────────────────────────────────────────────────────────
class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// ── Bottom bar com pill deslizante ────────────────────────────────────────────
class _SlidingTabBar extends StatelessWidget {
  const _SlidingTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.color,
    required this.onTap,
  });

  final int selectedIndex;
  final List<_TabItem> tabs;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;

        return Stack(
          children: [
            // ── Pill deslizante ───────────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              left: tabWidth * selectedIndex + tabWidth * 0.15,
              top: 6,
              width: tabWidth * 0.7,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // ── Ícones e labels ───────────────────────────────────────────
            Row(
              children: List.generate(tabs.length, (i) {
                final selected = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: Icon(
                              tabs[i].icon,
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tabs[i].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

CustomTransitionPage<void> _sharedAxisPage({
  required LocalKey key,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        ),
  );
}
