import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/transect_record_model.dart';
import '../../data/services/transect_handoff_codec.dart';
import '../controllers/transects_controller.dart';

class TransectPassPage extends StatelessWidget {
  const TransectPassPage({super.key, required this.record});
  final TransectRecordModel record;

  @override
  Widget build(BuildContext context) {
    final frames = TransectHandoffCodec.encode(record);
    return _FramesPage(record: record, frames: frames);
  }
}

class _FramesPage extends StatefulWidget {
  const _FramesPage({required this.record, required this.frames});
  final TransectRecordModel record;
  final List<String> frames;

  @override
  State<_FramesPage> createState() => _FramesPageState();
}

class _FramesPageState extends State<_FramesPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PASS transect')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.record.transectName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${widget.record.totalDistanceM.toStringAsFixed(1)} m completed · ${widget.record.remainingDistanceM.toStringAsFixed(1)} m remaining',
        ),
        const SizedBox(height: 20),
        Center(
          child: QrImageView(
            data: widget.frames[index],
            version: QrVersions.auto,
            size: 300,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'QR ${index + 1} of ${widget.frames.length}. Keep this screen open until the next user scans every QR.',
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: index == 0 ? null : () => setState(() => index--),
              child: const Text('Previous'),
            ),
            TextButton(
              onPressed: index + 1 == widget.frames.length
                  ? null
                  : () => setState(() => index++),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

class TransectReceivePage extends ConsumerStatefulWidget {
  const TransectReceivePage({super.key});
  @override
  ConsumerState<TransectReceivePage> createState() =>
      _TransectReceivePageState();
}

class _TransectReceivePageState extends ConsumerState<TransectReceivePage> {
  final scanner = MobileScannerController();
  final frames = <int, TransectHandoffFrame>{};
  String? identity;
  String? message;
  bool importing = false;

  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }

  Future<void> _scan(BarcodeCapture capture) async {
    if (importing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    try {
      final frame = TransectHandoffCodec.parse(raw);
      final key = '${frame.localId}:${frame.sequence}';
      if (identity != null && identity != key) {
        throw const FormatException('This QR belongs to a different handoff.');
      }
      if (frames.containsKey(frame.index)) return;
      setState(() {
        identity = key;
        frames[frame.index] = frame;
        message = '${frames.length} of ${frame.count} QR codes scanned';
      });
      if (frames.length != frame.count) return;
      importing = true;
      final record = TransectHandoffCodec.decode(frames.values.toList());
      final auth = ref.read(authControllerProvider);
      final imported = await ref
          .read(transectsControllerProvider.notifier)
          .importHandoff(
        record.copyWith(
          ownerUserIdOverride: auth.user?.id,
          ownerUserEmailOverride: auth.user?.email,
          researcherName: auth.user?.name,
        ),
          );
      if (!mounted) return;
      if (imported) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => message =
              'This handoff is already imported or older than the saved copy.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      importing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receive transect')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(controller: scanner, onDetect: _scan),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message ?? 'Scan the PASS QR code on the other device.'),
        ),
      ],
    ),
  );
}
