class OfflineSyncItem {
  const OfflineSyncItem({
    required this.id,
    required this.type,
    required this.payloadJson,
    required this.status,
    required this.createdAt,
    this.lastAttemptAt,
    this.syncedAt,
    this.deletedAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  static const typeScanRecordMockSave = 'scan_record_mock_save';
  static const statusPending = 'pending';
  static const statusSyncing = 'syncing';
  static const statusSynced = 'synced';
  static const statusFailed = 'failed';

  final String id;
  final String type;
  final String payloadJson;
  final String status;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final DateTime? deletedAt;
  final int retryCount;
  final String? errorMessage;

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) {
    return OfflineSyncItem(
      id: _asString(json['id']),
      type: _asString(json['type'], fallback: typeScanRecordMockSave),
      payloadJson: _asString(json['payload_json'] ?? json['payloadJson']),
      status: _asString(json['status'], fallback: statusPending),
      createdAt:
          _asDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      lastAttemptAt: _asDate(json['last_attempt_at'] ?? json['lastAttemptAt']),
      syncedAt: _asDate(json['synced_at'] ?? json['syncedAt']),
      deletedAt: _asDate(json['deleted_at'] ?? json['deletedAt']),
      retryCount: _asInt(json['retry_count'] ?? json['retryCount']),
      errorMessage: _asNullableString(
        json['error_message'] ?? json['errorMessage'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'payload_json': payloadJson,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'retry_count': retryCount,
      'error_message': errorMessage,
    };
  }

  OfflineSyncItem copyWith({
    String? id,
    String? type,
    String? payloadJson,
    String? status,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    DateTime? syncedAt,
    DateTime? deletedAt,
    int? retryCount,
    String? errorMessage,
    bool clearError = false,
    bool clearSyncedAt = false,
    bool clearDeletedAt = false,
  }) {
    return OfflineSyncItem(
      id: id ?? this.id,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: clearSyncedAt ? null : syncedAt ?? this.syncedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

String? _asNullableString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

DateTime? _asDate(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
