import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_logo.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../capture/presentation/controllers/capture_controller.dart';
import '../../data/models/mock_ai_prediction_response.dart';
import '../../data/models/species_education_model.dart';
import '../../data/repositories/species_education_repository.dart';
import '../../data/services/offline_prediction_service.dart';

class GuestScanPage extends ConsumerStatefulWidget {
  const GuestScanPage({super.key});

  @override
  ConsumerState<GuestScanPage> createState() => _GuestScanPageState();
}

class _GuestScanPageState extends ConsumerState<GuestScanPage> {
  static const _parts = [
    _GuestPlantPart(
      'leaves',
      'Leaves',
      'Leaf shape and arrangement',
      Icons.eco_rounded,
    ),
    _GuestPlantPart(
      'bark',
      'Bark',
      'Trunk texture and color',
      Icons.forest_rounded,
    ),
    _GuestPlantPart(
      'roots',
      'Roots',
      'Roots and their structure',
      Icons.grass_rounded,
    ),
    _GuestPlantPart(
      'flowers',
      'Flowers',
      'Flowers or reproductive parts',
      Icons.local_florist_rounded,
    ),
  ];

  final _predictionService = OfflinePredictionService();
  final _resultKey = GlobalKey();
  String? _selectedPart;
  CapturedPlantPartImage? _image;
  MockAiPredictionResponse? _result;
  Future<SpeciesEducationModel>? _education;
  String? _error;
  bool _isWorking = false;

  void _togglePart(String part) {
    if (_isWorking) return;
    ref.read(captureControllerProvider.notifier).clearImages();
    setState(() {
      _selectedPart = _selectedPart == part ? null : part;
      _image = null;
      _result = null;
      _education = null;
      _error = null;
    });
  }

  Future<void> _scan({required bool camera}) async {
    final part = _selectedPart;
    if (_isWorking || part == null) return;

    final capture = ref.read(captureControllerProvider.notifier);
    final previousImage = ref.read(captureControllerProvider).getImageFor(part);
    setState(() {
      _isWorking = true;
      _error = null;
    });

    if (camera) {
      await capture.pickFromCamera(part);
    } else {
      await capture.pickFromGallery(part);
    }
    if (!mounted) return;

    final captureState = ref.read(captureControllerProvider);
    final image = captureState.getImageFor(part);
    if (image == null || identical(image, previousImage)) {
      setState(() {
        _isWorking = false;
        _error = captureState.errorMessage;
      });
      return;
    }

    setState(() {
      _image = image;
      _result = null;
      _education = null;
    });

    try {
      final result = await _predictionService.predict(
        imagePath: image.imagePath,
        previewBytes: image.previewBytes,
        plantParts: [part],
      );
      if (!mounted) return;
      final valid = result.isValidCnnResult;
      setState(() {
        _result = valid ? result : null;
        _education = valid
            ? SpeciesEducationRepository.instance.findOfflineByScientificName(
                result.topPrediction.scientificName,
              )
            : null;
        _error = valid
            ? null
            : '${result.rejectionMessage} ${result.rejectionRecommendation}';
      });
      if (valid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultContext = _resultKey.currentContext;
          if (mounted && resultContext != null) {
            Scrollable.ensureVisible(
              resultContext,
              duration: const Duration(milliseconds: 350),
              alignment: 0.12,
            );
          }
        });
      }
    } on OfflinePredictionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.reason == 'web_not_supported'
            ? 'Guest scanning is available in the Android app.'
            : 'The on-device identification could not run. Please try another photo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Identification is unavailable right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _openAuth(String routeName) {
    ref.read(captureControllerProvider.notifier).clearImages();
    setState(() {
      _image = null;
      _result = null;
      _education = null;
    });
    context.pushNamed(routeName);
  }

  void _openLogin() => _openAuth(RouteNames.login);

  void _openRegister() => _openAuth(RouteNames.register);

  @override
  Widget build(BuildContext context) {
    final top = _result?.topPrediction;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF7),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9FCFA), Color(0xFFEFF8F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  _hero(),
                  const SizedBox(height: 12),
                  _scanCard(top),
                  const SizedBox(height: 24),
                  Text(
                    'S M A L L  S C A N S .  B I G G E R  T O M O R R O W S .',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryDarkGreen,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const SilvamangLogo(size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SILVAMANG AI',
                maxLines: 1,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primaryDarkGreen,
                  fontSize: 18,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'MANGROVES FOR A BRIGHTER TOMORROW',
                maxLines: 2,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryDarkGreen,
                  fontSize: 8,
                  letterSpacing: 1.7,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 350;
        return SizedBox(
          height: narrow ? 450 : 344,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -16,
                left: 0,
                top: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: _HeroPhotoClipper(),
                  child: Image.asset(
                    'assets/images/guest_mangrove_hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFDDEEDD), Color(0xFF90B892)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.forest_rounded,
                          color: Color(0x88447951),
                          size: 140,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF5FBF7),
                        const Color(0xFFF5FBF7).withValues(alpha: 0.92),
                        const Color(0xFFF5FBF7).withValues(alpha: 0.08),
                      ],
                      stops: const [0, 0.47, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 26, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E X P L O R E   •   L E A R N   •   P R O T E C T',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDarkGreen,
                        fontSize: narrow ? 9 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Discover a\n'),
                          TextSpan(
                            text: 'mangrove',
                            style: TextStyle(
                              color: const Color(0xFF4B843A),
                              fontSize: narrow ? 40 : 47,
                            ),
                          ),
                        ],
                      ),
                      style: AppTextStyles.displayLarge.copyWith(
                        color: const Color(0xFF173B2C),
                        fontSize: narrow ? 40 : 47,
                        height: 0.98,
                        letterSpacing: -2.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: narrow ? 240 : 280,
                      child: Text(
                        'Identify mangrove species from a photo and learn more about nature around you.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF53616B),
                          fontSize: narrow ? 14 : 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 42,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF62A64C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'H E A L T H Y   M A N G R O V E S\n'
                      'B R I G H T E R   T O M O R R O W S',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDarkGreen,
                        fontSize: narrow ? 8 : 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scanCard(MockTopPrediction? top) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPart != null) ...[
            _photoArea(),
            const SizedBox(height: 22),
          ],
          Row(
            children: [
              Expanded(
                child: Text('Plant part', style: AppTextStyles.titleLarge),
              ),
              Tooltip(
                message:
                    'Choosing the plant part helps improve identification.',
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primaryDarkGreen,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Select the part of the plant in your photo.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [for (final part in _parts) _partChip(part)],
          ),
          if (_selectedPart != null) ...[
            const SizedBox(height: 22),
            _scanButton(
              label: 'Take photo',
              icon: Icons.camera_alt_rounded,
              filled: true,
              onPressed: _isWorking ? null : () => _scan(camera: true),
            ),
            const SizedBox(height: 10),
            _scanButton(
              label: 'Choose from gallery',
              icon: Icons.photo_library_outlined,
              filled: false,
              onPressed: _isWorking ? null : () => _scan(camera: false),
            ),
          ],
          if (_isWorking) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Identifying on this device...',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.dangerRed,
              ),
            ),
          ],
          if (_selectedPart != null && top != null) ...[
            const SizedBox(height: 18),
            _resultCard(top),
            if (_education != null) ...[
              const SizedBox(height: 14),
              FutureBuilder<SpeciesEducationModel>(
                future: _education,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const _EducationLoadingCard();
                  }
                  return _EducationCard(education: snapshot.data!);
                },
              ),
            ],
          ],
          const SizedBox(height: 24),
          _authActions(),
          const SizedBox(height: 16),
          _guestNotice(),
        ],
      ),
    );
  }

  Widget _photoArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxWidth < 300 ? 218 : 210,
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF0F9F2), Color(0xFFE7F5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _image != null
                    ? SizedBox.expand(
                        child: Image.memory(
                          _image!.previewBytes,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Stack(
                        children: [
                          Positioned(
                            left: -20,
                            bottom: -20,
                            child: Icon(
                              Icons.forest_rounded,
                              size: 116,
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.13,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -15,
                            bottom: -18,
                            child: Icon(
                              Icons.forest_rounded,
                              size: 132,
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.13,
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 62,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(
                                        alpha: 0.80,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryDarkGreen
                                              .withValues(alpha: 0.08),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: Color(0xFF9FC6A1),
                                      size: 37,
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Text(
                                    'Add a photo of a mangrove',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontSize: 17,
                                      color: const Color(0xFF18322D),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Take a photo or choose from your gallery\nto identify the species.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: const Color(0xFF53616B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _partChip(_GuestPlantPart part) {
    final selected = _selectedPart == part.key;
    return Tooltip(
      message: part.hint,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${part.title} photo options',
        child: Material(
          color: selected ? AppColors.primaryDarkGreen : AppColors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected
                  ? AppColors.primaryDarkGreen
                  : AppColors.borderSoft,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _isWorking ? null : () => _togglePart(part.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    part.icon,
                    size: 21,
                    color: selected
                        ? AppColors.white
                        : AppColors.primaryDarkGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    part.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: selected
                          ? AppColors.white
                          : const Color(0xFF1C2C31),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback? onPressed,
  }) {
    final content = Row(
      children: [
        Icon(icon, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: filled ? AppColors.white : AppColors.primaryDarkGreen,
              fontSize: 17,
            ),
          ),
        ),
        const Icon(Icons.arrow_forward_rounded, size: 22),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDarkGreen,
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                side: const BorderSide(
                  color: AppColors.primaryDarkGreen,
                  width: 1.4,
                ),
              ),
              child: content,
            ),
    );
  }

  Widget _authActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A6242), Color(0xFF064D35)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDarkGreen.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: InkWell(
              key: const Key('guest-login-button'),
              onTap: _openLogin,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          color: AppColors.white,
                          size: 25,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Login',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Save your records and access all field tools',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withValues(alpha: 0.84),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            Text(
              'New to SILVAMANG AI?',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
            ),
            TextButton(
              key: const Key('guest-register-button'),
              onPressed: _openRegister,
              child: const Text('Create account'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _guestNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: const BoxDecoration(
              color: Color(0xFFDDEEE2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.primaryDarkGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Guest scans identify species and show learning material.\n',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: 'Sign in to save field records.'),
                ],
              ),
              style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(MockTopPrediction top) {
    return Container(
      key: _resultKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text('SPECIES ESTIMATE', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            top.scientificName.replaceAll('_', ' '),
            style: AppTextStyles.titleLarge,
          ),
          if (top.commonName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(top.commonName, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${top.confidence.toStringAsFixed(1)}% model confidence',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDarkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestPlantPart {
  const _GuestPlantPart(this.key, this.title, this.hint, this.icon);

  final String key;
  final String title;
  final String hint;
  final IconData icon;
}

class _HeroPhotoClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.72, 0)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.18,
        size.width * 0.30,
        size.height * 0.47,
      )
      ..quadraticBezierTo(0, size.height * 0.72, 0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8D5BB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
          const Radius.circular(18),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 12) {
        final end = start + 7 < metric.length ? start + 7 : metric.length;
        canvas.drawPath(metric.extractPath(start, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EducationLoadingCard extends StatelessWidget {
  const _EducationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const LinearProgressIndicator(),
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({required this.education});

  final SpeciesEducationModel education;

  @override
  Widget build(BuildContext context) {
    final habitat = education.habitat.take(2).join(' ');
    final characteristic = education.leafCharacteristics.isNotEmpty
        ? education.leafCharacteristics
        : education.rootCharacteristics.isNotEmpty
        ? education.rootCharacteristics
        : education.physicalCharacteristics.take(2).join(' ');
    final ecologicalRole = education.ecologicalImportance.isEmpty
        ? ''
        : education.ecologicalImportance.first;
    final conservation = education.conservationNote.isNotEmpty
        ? education.conservationNote
        : education.conservationInformation.isEmpty
        ? ''
        : education.conservationInformation.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Learn about this mangrove',
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          if (education.isFallback) ...[
            const SizedBox(height: 8),
            Text(
              'General mangrove information',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (!education.isFallback && education.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(education.description, style: AppTextStyles.bodyMedium),
          ],
          if (habitat.isNotEmpty)
            _EducationFact(
              icon: Icons.water_rounded,
              title: 'Habitat',
              text: habitat,
            ),
          if (characteristic.isNotEmpty && !education.isFallback)
            _EducationFact(
              icon: Icons.visibility_outlined,
              title: 'How to recognize it',
              text: characteristic,
            ),
          if (ecologicalRole.isNotEmpty)
            _EducationFact(
              icon: Icons.nature_people_rounded,
              title: 'Why it matters',
              text: ecologicalRole,
            ),
          if (conservation.isNotEmpty)
            _EducationFact(
              icon: Icons.volunteer_activism_rounded,
              title: 'Protect it',
              text: conservation,
            ),
        ],
      ),
    );
  }
}

class _EducationFact extends StatelessWidget {
  const _EducationFact({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 3),
                Text(text, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
