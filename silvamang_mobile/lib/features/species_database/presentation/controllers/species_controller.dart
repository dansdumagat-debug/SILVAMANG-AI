import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/species_model.dart';
import '../../data/repositories/species_repository.dart';

final speciesControllerProvider =
    StateNotifierProvider<SpeciesController, SpeciesState>((ref) {
      return SpeciesController(
        repository: ref.watch(speciesRepositoryProvider),
      );
    });

class SpeciesState {
  const SpeciesState({
    this.species = const [],
    this.selectedSpecies,
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  final List<SpeciesModel> species;
  final SpeciesModel? selectedSpecies;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  SpeciesState copyWith({
    List<SpeciesModel>? species,
    SpeciesModel? selectedSpecies,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    bool clearSelectedSpecies = false,
    bool clearError = false,
  }) {
    return SpeciesState(
      species: species ?? this.species,
      selectedSpecies: clearSelectedSpecies
          ? null
          : selectedSpecies ?? this.selectedSpecies,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SpeciesController extends StateNotifier<SpeciesState> {
  SpeciesController({required this.repository}) : super(const SpeciesState());

  final SpeciesRepository repository;

  Future<void> loadSpecies() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final species = await repository.getSpecies(search: state.searchQuery);
      state = state.copyWith(species: species, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> searchSpecies(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadSpecies();
  }

  Future<void> loadSpeciesById(int id) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSelectedSpecies: true,
    );
    try {
      final species = await repository.getSpeciesById(id);
      state = state.copyWith(selectedSpecies: species, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
