import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/capture/presentation/pages/capture_guide_page.dart';
import '../../features/capture/presentation/pages/manual_species_measurement_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/identification/presentation/pages/identification_result_page.dart';
import '../../features/identification/presentation/pages/guest_scan_page.dart';
import '../../features/identification/presentation/pages/offline_model_diagnostic_page.dart';
import '../../features/location_validation/presentation/pages/location_validation_page.dart';
import '../../features/map/presentation/pages/offline_map_manager_page.dart';
import '../../features/map/presentation/pages/map_records_page.dart';
import '../../features/measurements/presentation/pages/camera_pointing_measurement_page.dart';
import '../../features/measurements/presentation/pages/measurement_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/offline_sync/presentation/pages/offline_queue_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/records/presentation/pages/record_detail_page.dart';
import '../../features/records/presentation/pages/records_page.dart';
import '../../features/settings/presentation/pages/app_settings_page.dart';
import '../../features/settings/presentation/pages/help_about_page.dart';
import '../../features/species_database/presentation/pages/species_detail_page.dart';
import '../../features/species_database/presentation/pages/species_list_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/transects/presentation/pages/create_transect_page.dart';
import '../../features/transects/presentation/pages/transect_detail_page.dart';
import '../../features/transects/presentation/pages/transect_history_page.dart';
import '../widgets/bottom_nav_shell.dart';
import '../services/local_storage_service.dart';
import 'route_names.dart';

class AppRouter {
  const AppRouter._();

  static final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      const publicPaths = {'/', '/guest', '/login', '/register'};
      if (publicPaths.contains(state.uri.path)) return null;
      final token = LocalStorageService.instance.getToken();
      return token == null || token.isEmpty ? '/guest' : null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/guest',
        name: RouteNames.guestScan,
        builder: (context, state) => const GuestScanPage(),
      ),
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            BottomNavShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/capture-guide',
            name: RouteNames.captureGuide,
            builder: (context, state) => CaptureGuidePage(
              transectLocalId: state.uri.queryParameters['transectId'],
            ),
          ),
          GoRoute(
            path: '/manual-species-measurement',
            name: RouteNames.manualSpeciesMeasurement,
            builder: (context, state) {
              final species = state.extra is Map<String, String>
                  ? state.extra! as Map<String, String>
                  : const <String, String>{};
              return ManualSpeciesMeasurementPage(
                scientificName: species['scientificName'] ?? '',
                commonName: species['commonName'] ?? '',
                transectLocalId: state.uri.queryParameters['transectId'],
              );
            },
          ),
          GoRoute(
            path: '/identification-result',
            name: RouteNames.identificationResult,
            builder: (context, state) => IdentificationResultPage(
              transectLocalId: state.uri.queryParameters['transectId'],
            ),
          ),
          GoRoute(
            path: '/offline-model-diagnostic',
            name: RouteNames.offlineModelDiagnostic,
            builder: (context, state) => const OfflineModelDiagnosticPage(),
          ),
          GoRoute(
            path: '/measurement',
            name: RouteNames.measurement,
            builder: (context, state) => const MeasurementPage(),
          ),
          GoRoute(
            path: '/camera-pointing-measurement',
            name: RouteNames.cameraPointingMeasurement,
            builder: (context, state) => CameraPointingMeasurementPage(
              initialType: state.uri.queryParameters['type'],
              resultOnly: state.uri.queryParameters['result_only'] == 'true',
              axisLabel: state.uri.queryParameters['axis'] == '1'
                  ? 'Canopy 1 (m)'
                  : state.uri.queryParameters['axis'] == '2'
                  ? 'Canopy 2 (m)'
                  : null,
            ),
          ),
          GoRoute(
            path: '/location-validation',
            name: RouteNames.locationValidation,
            builder: (context, state) => const LocationValidationPage(),
          ),
          GoRoute(
            path: '/ai-assistant',
            name: RouteNames.aiAssistant,
            builder: (context, state) => AiAssistantPage(
              scanRecordId: state.uri.queryParameters['scan_record_id'],
              initialPrompt: state.uri.queryParameters['prompt'],
            ),
          ),
          GoRoute(
            path: '/records',
            name: RouteNames.records,
            builder: (context, state) => const RecordsPage(),
          ),
          GoRoute(
            path: '/records/:id',
            name: RouteNames.recordDetail,
            builder: (context, state) =>
                RecordDetailPage(recordId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/species',
            name: RouteNames.speciesList,
            builder: (context, state) => const SpeciesListPage(),
          ),
          GoRoute(
            path: '/species/:id',
            name: RouteNames.speciesDetail,
            builder: (context, state) =>
                SpeciesDetailPage(speciesId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/map',
            name: RouteNames.map,
            builder: (context, state) => const MapRecordsPage(),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/notifications',
            name: RouteNames.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/settings',
            name: RouteNames.appSettings,
            builder: (context, state) => const AppSettingsPage(),
          ),
          GoRoute(
            path: '/help-about',
            name: RouteNames.helpAbout,
            builder: (context, state) => const HelpAboutPage(),
          ),
          GoRoute(
            path: '/offline-queue',
            name: RouteNames.offlineQueue,
            builder: (context, state) => const OfflineQueuePage(),
          ),
          GoRoute(
            path: '/offline-map-manager',
            name: RouteNames.offlineMapManager,
            builder: (context, state) => const OfflineMapManagerPage(),
          ),
          GoRoute(
            path: '/transects',
            name: RouteNames.transects,
            builder: (context, state) => const TransectHistoryPage(),
          ),
          GoRoute(
            path: '/transects/create',
            name: RouteNames.transectCreate,
            builder: (context, state) => const CreateTransectPage(),
          ),
          GoRoute(
            path: '/transects/:id',
            name: RouteNames.transectDetail,
            builder: (context, state) => TransectDetailPage(
              transectId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),
    ],
  );
}
