import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../data/repositories/local_draft_repository.dart';
import '../data/repositories/speed_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/speed/speed_session_controller.dart';
import '../features/speed/speed_session_detail_screen.dart';
import '../features/speed/speed_session_screen.dart';
import '../features/speed/speed_ready_screen.dart';
import '../features/speed/speed_setup_screen.dart';
import '../features/editor/route_editor_controller.dart';
import '../features/editor/route_editor_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_shell.dart';
import '../features/free_ride/free_ride_controller.dart';
import '../features/free_ride/free_ride_screen.dart';
import '../features/session/live_session_controller.dart';
import '../features/session/live_session_screen.dart';
import '../features/garage/garage_screen.dart';
import '../features/logs/logs_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../services/logging/app_logger.dart';
import '../services/auth/auth_service.dart';
import '../services/garage/garage_service.dart';
import '../services/locale/locale_controller.dart';
import '../services/official_routes/official_routes_service.dart';
import '../services/settings/app_settings_controller.dart';
import '../services/geocoding/reverse_geocoding_service.dart';
import '../services/routing/elevation_service.dart';
import '../services/routing/routing_service.dart';
import '../features/profile/complete_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../services/profile/profile_service.dart';
import '../services/sync/sync_service.dart';

class AppRouter {
  AppRouter({
    required this.repository,
    required this.speedRepository,
    required this.config,
    required this.localeController,
    required this.settingsController,
    required this.refreshListenable,
    this.authService,
    this.officialRoutesService,
    SyncService? syncService,
    ProfileService? profileService,
    GarageService? garageService,
  })  : _editorController = RouteEditorController(
          repository,
          routingService: config.hasMapbox
              ? RoutingService(mapboxToken: config.mapboxToken!)
              : null,
          geocodingService: config.hasMapbox
              ? ReverseGeocodingService(accessToken: config.mapboxToken!)
              : null,
          elevationService: ElevationService(),
          defaultRoutingProfile: settingsController.defaultRoutingProfile,
          officialRoutesService: officialRoutesService,
        ),
        _sessionController = LiveSessionController(repository),
        _freeRideController = FreeRideController(
          repository,
          geocodingService: config.hasMapbox
              ? ReverseGeocodingService(accessToken: config.mapboxToken!)
              : null,
          routingService: config.hasMapbox
              ? RoutingService(mapboxToken: config.mapboxToken!)
              : null,
        ) {
    if (syncService != null) this.syncService = syncService;
    if (profileService != null) this.profileService = profileService;
    if (garageService != null) this.garageService = garageService;
  }

  final LocalDraftRepository repository;
  final SpeedRepository speedRepository;
  final AppConfig config;
  final LocaleController localeController;
  final AppSettingsController settingsController;
  final Listenable refreshListenable;
  final AuthService? authService;
  final OfficialRoutesService? officialRoutesService;
  ProfileService? profileService;
  GarageService? garageService;
  late final RouteEditorController _editorController;
  late final LiveSessionController _sessionController;
  late final FreeRideController _freeRideController;

  SyncService? _syncService;

  /// Mutable so [SplitwayApp] can attach/detach after login/logout.
  /// Propagates to [_editorController] so route deletions also hit the remote.
  SyncService? get syncService => _syncService;
  set syncService(SyncService? value) {
    _syncService = value;
    _editorController.syncService = value;
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/routes',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isLoggedIn = authService?.isLoggedIn ?? false;
      if (!isLoggedIn) return null;

      final isComplete = profileService?.isComplete;
      // null = haven't checked yet. Don't redirect; let the current
      // navigation proceed. The refresh listenable will re-run this
      // callback once refreshCompleteness() resolves.
      if (isComplete == null) return null;

      final path = state.uri.path;
      if (!isComplete && path != '/complete-profile') {
        return '/complete-profile';
      }
      if (isComplete && path == '/complete-profile') {
        return '/routes';
      }
      return null;
    },
    routes: [
      // Login screen (outside the shell — no bottom nav).
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          final banner = state.uri.queryParameters['message'];
          return LoginScreen(
            authService: authService!,
            redirect: redirect,
            bannerMessage: banner,
          );
        },
      ),

      // Onboarding — only reachable when logged in + profile incomplete.
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => CompleteProfileScreen(
          authService: authService!,
          profileService: profileService!,
        ),
      ),

      GoRoute(
        path: '/settings',
        builder: (_, __) => SettingsScreen(
          localeController: localeController,
          settingsController: settingsController,
          authService: authService,
          repository: repository,
          garageService: garageService,
          profileService: profileService,
        ),
      ),

      GoRoute(
        path: '/settings/logs',
        builder: (_, __) {
          final sink = AppLogger.localSink;
          final uploader = AppLogger.uploader;
          if (sink == null || uploader == null) {
            return const Scaffold(
              body: Center(child: Text('Logger not initialized')),
            );
          }
          return LogsScreen(
            sink: sink,
            uploader: uploader,
            profileService: profileService,
          );
        },
      ),

      GoRoute(
        path: '/profile',
        builder: (_, __) => ProfileScreen(
          profileService: profileService!,
          authService: authService!,
        ),
      ),

      GoRoute(
        path: '/garage',
        builder: (_, __) => GarageScreen(
          garageService: garageService!,
          config: config,
          authService: authService,
          profileService: profileService,
        ),
      ),

      GoRoute(
        path: '/stats',
        builder: (_, __) => StatsScreen(
          repository: repository,
          settingsController: settingsController,
          speedRepository: speedRepository,
          garageService: garageService,
          authService: authService,
        ),
      ),

      // Velocidad (drag-strip measurements).
      GoRoute(
        path: '/speed',
        builder: (context, _) => SpeedSetupScreen(
          garageService: garageService,
          onContinue: (result) {
            final controller = SpeedSessionController(
              userId: authService?.currentUser?.id,
              vehicleId: result.vehicle.id,
              vehicleName: result.vehicle.name,
              metrics: result.metrics,
              countdownSeconds: result.countdownSeconds,
              userProvidedName: result.name,
              repository: speedRepository,
            );
            context.push(
              '/speed/ready',
              extra: _SpeedNavExtra(
                controller: controller,
                view: result.view,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/speed/ready',
        builder: (context, state) {
          final extra = state.extra as _SpeedNavExtra;
          return SpeedReadyScreen(
            onStart: () => context.pushReplacement(
              '/speed/session',
              extra: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: '/speed/session',
        builder: (context, state) {
          final extra = state.extra as _SpeedNavExtra;
          return SpeedSessionScreen(
            controller: extra.controller,
            view: extra.view,
            onSaved: (id) => context.go('/history/speed/$id'),
            onDiscarded: () => context.go('/routes'),
            onCancelled: () => context.go('/routes'),
          );
        },
      ),
      GoRoute(
        path: '/history/speed/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FutureBuilder(
            future: speedRepository.getById(id),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final s = snap.data;
              if (s == null) {
                return const Scaffold(
                  body: Center(child: Text('Not found')),
                );
              }
              return SpeedSessionDetailScreen(
                session: s,
                repository: speedRepository,
              );
            },
          );
        },
      ),

      // Main tabbed shell.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(
          shell: shell,
          authService: authService,
          syncService: syncService,
          profileService: profileService,
          settingsController: settingsController,
          routeEditorController: _editorController,
          sessionController: _sessionController,
          freeRideController: _freeRideController,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/routes',
                builder: (_, __) => RouteEditorScreen(
                  controller: _editorController,
                  config: config,
                  authService: authService,
                  profileService: profileService,
                  settingsController: settingsController,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/session',
                builder: (_, __) => LiveSessionScreen(
                  controller: _sessionController,
                  config: config,
                  authService: authService,
                  profileService: profileService,
                  garageService: garageService,
                  settingsController: settingsController,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/free-ride',
                builder: (_, __) => FreeRideScreen(
                  controller: _freeRideController,
                  config: config,
                  authService: authService,
                  profileService: profileService,
                  garageService: garageService,
                  settingsController: settingsController,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => HistoryScreen(
                  repository: repository,
                  config: config,
                  authService: authService,
                  profileService: profileService,
                  garageService: garageService,
                  speedRepository: speedRepository,
                  syncService: syncService,
                  settingsController: settingsController,
                  routingService: config.hasMapbox
                      ? RoutingService(mapboxToken: config.mapboxToken!)
                      : null,
                  initialTab: state.uri.queryParameters['tab'] == 'speed'
                      ? 'speed'
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  void dispose() {
    _editorController.dispose();
    _sessionController.dispose();
    _freeRideController.dispose();
  }
}

class _SpeedNavExtra {
  const _SpeedNavExtra({required this.controller, required this.view});
  final SpeedSessionController controller;
  final SpeedView view;
}

/// Helper to check auth and navigate to login if needed.
///
/// Returns `true` if the user is already logged in or successfully logged in
/// after being redirected, `false` if they skipped.
Future<bool> requireAuth(
  BuildContext context,
  AuthService? authService, {
  required String message,
}) async {
  if (authService == null || authService.isLoggedIn) return true;

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        authService: authService,
        bannerMessage: message,
      ),
    ),
  );
  return result == true;
}
