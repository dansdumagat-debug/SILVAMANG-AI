import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  static const _connectivityService = ConnectivityService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final offlineState = ref.watch(offlineSyncControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.profile,
        ),
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  icon: Icons.person_rounded,
                  title: 'Account',
                  trailing: SilvamangBadge(
                    label: authState.isOfflineSession ? 'Offline' : 'Active',
                    type: authState.isOfflineSession
                        ? SilvamangBadgeType.warning
                        : SilvamangBadgeType.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsRow(
                  label: 'Name',
                  value: authState.user?.name.isNotEmpty == true
                      ? authState.user!.name
                      : 'Not available',
                ),
                _SettingsRow(
                  label: 'Email',
                  value: authState.user?.email.isNotEmpty == true
                      ? authState.user!.email
                      : 'Not available',
                ),
                _SettingsRow(
                  label: 'Role',
                  value: authState.user?.roles.isNotEmpty == true
                      ? authState.user!.roles.first
                      : 'Mobile User',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: FutureBuilder<_ConnectionStatus>(
              future: _loadConnectionStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.wifi_rounded,
                      title: 'Connection',
                      trailing: SilvamangBadge(
                        label: status == null
                            ? 'Checking'
                            : status.apiReachable
                                ? 'Online'
                                : 'Offline',
                        type: status?.apiReachable == true
                            ? SilvamangBadgeType.success
                            : SilvamangBadgeType.warning,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SettingsRow(
                      label: 'Network',
                      value: status == null
                          ? 'Checking...'
                          : status.hasNetwork
                              ? 'Connected'
                              : 'Unavailable',
                    ),
                    _SettingsRow(
                      label: 'Server',
                      value: status == null
                          ? 'Checking...'
                          : status.apiReachable
                              ? 'Reachable'
                              : 'Not reachable',
                    ),
                    _SettingsRow(label: 'API URL', value: _apiBaseUrl()),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.storage_rounded,
                  title: 'Offline Tools',
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingsAction(
                  icon: Icons.notifications_rounded,
                  title: 'Notification Center',
                  onTap: () => context.pushNamed(RouteNames.notifications),
                ),
                _SettingsRow(
                  label: 'Pending queue',
                  value: '${offlineState.pendingCount} item(s)',
                ),
                _SettingsAction(
                  icon: Icons.cloud_queue_rounded,
                  title: 'Open Offline Queue',
                  onTap: () => context.pushNamed(RouteNames.offlineQueue),
                ),
                _SettingsAction(
                  icon: Icons.download_for_offline_rounded,
                  title: 'Manage Offline Maps',
                  onTap: () => context.pushNamed(RouteNames.offlineMapManager),
                ),
                _SettingsAction(
                  icon: Icons.map_rounded,
                  title: 'View Scan Pins',
                  onTap: () => context.pushNamed(RouteNames.map),
                ),
                _SettingsAction(
                  icon: Icons.memory_rounded,
                  title: 'Offline Model Diagnostic',
                  onTap: () =>
                      context.pushNamed(RouteNames.offlineModelDiagnostic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<_ConnectionStatus> _loadConnectionStatus() async {
    final hasNetwork = await _connectivityService.hasNetworkConnection();
    final apiReachable = await _connectivityService.isOnline();
    return _ConnectionStatus(
      hasNetwork: hasNetwork,
      apiReachable: apiReachable,
    );
  }

  String _apiBaseUrl() {
    const dartDefinedUrl = String.fromEnvironment('API_BASE_URL');
    final definedUrl = dartDefinedUrl.trim();
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }

    final envUrl = dotenv.env['API_BASE_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    return 'http://10.0.2.2:8000/api';
  }
}

class _ConnectionStatus {
  const _ConnectionStatus({
    required this.hasNetwork,
    required this.apiReachable,
  });

  final bool hasNetwork;
  final bool apiReachable;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryDarkGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelLarge,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryDarkGreen),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: AppTextStyles.labelLarge)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}
