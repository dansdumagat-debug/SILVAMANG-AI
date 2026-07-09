import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/scan_record_model.dart';
import '../../data/repositories/scan_record_repository.dart';

final recordsControllerProvider =
    StateNotifierProvider<RecordsController, RecordsState>((ref) {
      return RecordsController(
        repository: ref.watch(scanRecordRepositoryProvider),
      );
    });

class RecordsState {
  const RecordsState({
    this.records = const [],
    this.selectedRecord,
    this.isLoading = false,
    this.isRevalidating = false,
    this.errorMessage,
    this.successMessage,
    this.searchQuery = '',
    this.selectedFilter = 'All',
  });

  final List<ScanRecordModel> records;
  final ScanRecordModel? selectedRecord;
  final bool isLoading;
  final bool isRevalidating;
  final String? errorMessage;
  final String? successMessage;
  final String searchQuery;
  final String selectedFilter;

  RecordsState copyWith({
    List<ScanRecordModel>? records,
    ScanRecordModel? selectedRecord,
    bool? isLoading,
    bool? isRevalidating,
    String? errorMessage,
    String? successMessage,
    String? searchQuery,
    String? selectedFilter,
    bool clearSelectedRecord = false,
    bool clearError = false,
  }) {
    return RecordsState(
      records: records ?? this.records,
      selectedRecord: clearSelectedRecord
          ? null
          : selectedRecord ?? this.selectedRecord,
      isLoading: isLoading ?? this.isLoading,
      isRevalidating: isRevalidating ?? this.isRevalidating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearError ? null : successMessage ?? this.successMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class RecordsController extends StateNotifier<RecordsState> {
  RecordsController({required this.repository}) : super(const RecordsState());

  final ScanRecordRepository repository;

  Future<void> loadRecords() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await repository.getScanRecords(
        search: state.searchQuery,
        identificationStatus: _identificationStatusFor(state.selectedFilter),
        validationStatus: _validationStatusFor(state.selectedFilter),
      );
      state = state.copyWith(records: records, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> searchRecords(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadRecords();
  }

  Future<void> filterRecords(String filter) async {
    state = state.copyWith(selectedFilter: filter);
    await loadRecords();
  }

  Future<void> loadRecordById(int id) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSelectedRecord: true,
    );
    try {
      final record = await repository.getScanRecordById(id);
      state = state.copyWith(selectedRecord: record, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> revalidateSelectedRecord() async {
    final record = state.selectedRecord;
    if (record == null) {
      return;
    }

    state = state.copyWith(
      isRevalidating: true,
      clearError: true,
      successMessage: null,
    );
    try {
      final updatedRecord = await repository.validateScanRecordLocation(
        record.id,
      );
      state = state.copyWith(
        selectedRecord: updatedRecord,
        isRevalidating: false,
        successMessage: 'Location validation updated successfully.',
      );
    } catch (error) {
      state = state.copyWith(
        isRevalidating: false,
        errorMessage: error.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String? _identificationStatusFor(String filter) {
    return switch (filter) {
      'Completed' => 'completed',
      'Pending' => 'pending',
      _ => null,
    };
  }

  String? _validationStatusFor(String filter) {
    return switch (filter) {
      'Match' => 'match',
      'Mismatch' => 'mismatch',
      _ => null,
    };
  }
}
