import 'dart:convert';
import 'dart:io';

import '../models/transect_record_model.dart';

class TransectHandoffCodec {
  static const chunkSize = 600;

  static List<String> encode(TransectRecordModel record) {
    final bytes = zlib.encode(utf8.encode(jsonEncode(record.toJson())));
    final payload = base64Url.encode(bytes);
    final count = (payload.length / chunkSize).ceil();
    return List.generate(count, (index) {
      final start = index * chunkSize;
      final end = (start + chunkSize).clamp(0, payload.length);
      return 'SMT1|${record.localId}|${record.handoffSequence}|$index|$count|${payload.substring(start, end)}';
    });
  }

  static TransectHandoffFrame parse(String raw) {
    final parts = raw.split('|');
    if (parts.length != 6 || parts[0] != 'SMT1') {
      throw const FormatException('This is not a transect handoff QR.');
    }
    final sequence = int.tryParse(parts[2]);
    final index = int.tryParse(parts[3]);
    final count = int.tryParse(parts[4]);
    if (parts[1].isEmpty ||
        sequence == null ||
        index == null ||
        count == null ||
        count < 1 ||
        count > 2000 ||
        index < 0 ||
        index >= count) {
      throw const FormatException('Invalid transect handoff frame.');
    }
    return TransectHandoffFrame(parts[1], sequence, index, count, parts[5]);
  }

  static TransectRecordModel decode(List<TransectHandoffFrame> frames) {
    if (frames.isEmpty || frames.length != frames.first.count) {
      throw const FormatException('Some QR frames are missing.');
    }
    final first = frames.first;
    final ordered = List<TransectHandoffFrame?>.filled(first.count, null);
    for (final frame in frames) {
      if (frame.localId != first.localId ||
          frame.sequence != first.sequence ||
          frame.count != first.count ||
          ordered[frame.index] != null) {
        throw const FormatException('QR frames do not belong to one handoff.');
      }
      ordered[frame.index] = frame;
    }
    if (ordered.contains(null)) {
      throw const FormatException('Some QR frames are missing.');
    }
    final encoded = ordered.map((frame) => frame!.data).join();
    final json = jsonDecode(
      utf8.decode(zlib.decode(base64Url.decode(encoded))),
    );
    final record = TransectRecordModel.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
    if (record.localId != first.localId ||
        record.handoffSequence != first.sequence ||
        !record.isHandoffTransect ||
        record.status == TransectRecordModel.statusCompleted) {
      throw const FormatException('Invalid or completed transect handoff.');
    }
    return record;
  }
}

class TransectHandoffFrame {
  const TransectHandoffFrame(
    this.localId,
    this.sequence,
    this.index,
    this.count,
    this.data,
  );
  final String localId;
  final int sequence;
  final int index;
  final int count;
  final String data;
}
