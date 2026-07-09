import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/capture/presentation/pages/capture_guide_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/identification/presentation/pages/identification_result_page.dart';
import '../../features/location_validation/presentation/pages/location_validation_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/measurements/presentation/pages/measurement_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/records/presentation/pages/record_detail_page.dart';
import '../../features/records/presentation/pages/records_page.dart';
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
            path: '/identification-result',
            name: RouteNames.identificationResult,
            builder: (context, state) => const IdentificationResultPage(),
          ),
          GoRoute(
            path: '/measurement',
            name: RouteNames.measurement,
            builder: (context, state) => const MeasurementPage(),
          ),
          GoRoute(
            path: '/location-validation',
            name: RouteNames.locationValidation,
            builder: (context, state) => const LocationValidationPage(),
          ),
          GoRoute(
            path: '/ai-assistant',
            name: RouteNames.aiAssistant,
            builder: (context, state) => const AiAssistantPage(),
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
            builder: (context, state) => const MapPage(),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}
