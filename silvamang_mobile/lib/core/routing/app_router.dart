import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/capture/data/models/captured_plant_part_image.dart';
import '../../features/capture/presentation/pages/capture_guide_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/identification/presentation/pages/identification_result_page.dart';
import '../../features/identification/presentation/pages/offline_model_diagnostic_page.dart';
import '../../features/location_validation/presentation/pages/location_validation_page.dart';
import '../../features/map/presentation/pages/offline_map_manager_page.dart';
import '../../features/map/presentation/pages/map_records_page.dart';
import '../../features/measurement/presentation/pages/field_distance_page.dart';
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
import '../widgets/bottom_nav_shell.dart';
import 'route_names.dart';

class AppRouter {
  const AppRouter._();

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
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
            builder: (context, state) => const CaptureGuidePage(),
          ),
          GoRoute(
            path: '/field-distance',
            name: RouteNames.fieldDistance,
            builder: (context, state) => const FieldDistancePage(),
          ),
          GoRoute(
            path: '/identification-result',
            name: RouteNames.identificationResult,
            builder: (context, state) => const IdentificationResultPage(),
          ),
          GoRoute(
            path: '/offline-model-diagnostic',
            name: RouteNames.offlineModelDiagnostic,
            builder: (context, state) => const OfflineModelDiagnosticPage(),
          ),
          GoRoute(
            path: '/measurement',
            name: RouteNames.measurement,
            builder: (context, state) {
              final extra = state.extra;
              return MeasurementPage(
                initialImage: extra is CapturedPlantPartImage ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/camera-pointing-measurement',
            name: RouteNames.cameraPointingMeasurement,
            builder: (context, state) => CameraPointingMeasurementPage(
              initialType: state.uri.queryParameters['type'],
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
        ],
      ),
    ],
  );
}
