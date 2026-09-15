import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/species_taxonomy.dart';

final offlineMangroveKnowledgeServiceProvider =
    Provider<OfflineMangroveKnowledgeService>((ref) {
      return const OfflineMangroveKnowledgeService();
    });

class OfflineMangroveKnowledgeService {
  const OfflineMangroveKnowledgeService();

  static const String _knowledgeAssetPath =
      'assets/data/offline_mangrove_knowledge.json';
  static const String _panelSpeciesAssetPath =
      'assets/data/panel_mangrove_education.json';

  static List<OfflineMangroveKnowledgeEntry>? _cachedEntries;

  Future<OfflineMangroveKnowledgeAnswer> answer({
    required String question,
  }) async {
    final entries = await _loadEntries();
    final normalizedQuestion = _normalize(question);
    final questionTokens = _tokens(normalizedQuestion);

    OfflineMangroveKnowledgeEntry? bestEntry;
    var bestScore = 0;

    for (final entry in entries) {
      final score = _score(entry, normalizedQuestion, questionTokens);
      if (score > bestScore) {
        bestScore = score;
        bestEntry = entry;
      }
    }

    if (bestEntry == null || bestScore < 2) {
      return OfflineMangroveKnowledgeAnswer(
        response:
            "I don't have enough information about this topic yet. Please try another mangrove-related question.",
        intent: 'offline_unknown',
        relatedSpecies: const [],
        suggestedQuestions: const [
          'Why are mangroves important?',
          'How can I identify mangrove species?',
          'How can I protect mangroves?',
        ],
      );
    }

    return OfflineMangroveKnowledgeAnswer(
      response: _composeResponse(bestEntry),
      intent: bestEntry.category,
      relatedSpecies: bestEntry.relatedSpecies,
      suggestedQuestions: bestEntry.suggestedQuestions,
    );
  }

  Future<List<OfflineMangroveKnowledgeEntry>> _loadEntries() async {
    final cached = _cachedEntries;
    if (cached != null) {
      return cached;
    }

    final entries = <OfflineMangroveKnowledgeEntry>[];

    final rawKnowledge = await rootBundle.loadString(_knowledgeAssetPath);
    final decodedKnowledge = jsonDecode(rawKnowledge);
    if (decodedKnowledge is List) {
      entries.addAll(
        decodedKnowledge.whereType<Map<String, dynamic>>().map(
          OfflineMangroveKnowledgeEntry.fromJson,
        ),
      );
    }

    try {
      final rawSpecies = await rootBundle.loadString(_panelSpeciesAssetPath);
      final decodedSpecies = jsonDecode(rawSpecies);
      if (decodedSpecies is List) {
        entries.addAll(
          decodedSpecies.whereType<Map<String, dynamic>>().map(
            OfflineMangroveKnowledgeEntry.fromSpeciesEducationJson,
          ),
        );
      }
    } catch (_) {
      // The general offline assistant remains usable if this optional guide is absent.
    }

    _cachedEntries = entries.toList(growable: false);

    return _cachedEntries!;
  }

  int _score(
    OfflineMangroveKnowledgeEntry entry,
    String normalizedQuestion,
    Set<String> questionTokens,
  ) {
    var score = 0;
    final haystack = _normalize(
      [
        entry.category,
        entry.question,
        entry.answer,
        ...entry.keywords,
        ...entry.relatedSpecies,
      ].join(' '),
    );

    for (final token in questionTokens) {
      if (entry.keywords.map(_normalize).contains(token)) {
        score += 4;
      } else if (haystack.contains(token)) {
        score += 1;
      }
    }

    for (final species in entry.relatedSpecies) {
      final normalizedSpecies = _normalize(species);
      if (normalizedSpecies.isNotEmpty &&
          normalizedQuestion.contains(normalizedSpecies)) {
        score += 8;
      }
    }

    if (normalizedQuestion.contains(_normalize(entry.question))) {
      score += 10;
    }

    return score;
  }

  String _composeResponse(OfflineMangroveKnowledgeEntry entry) {
    final lines = <String>[entry.answer];

    if (entry.relatedSpecies.isNotEmpty) {
      lines.add('Related species: ${entry.relatedSpecies.join(', ')}.');
    }

    if (entry.suggestedQuestions.isNotEmpty) {
      lines.add('You can also ask: ${entry.suggestedQuestions.join(' | ')}');
    }

    return lines.join('\n\n');
  }

  String _normalize(String value) {
    return normalizedSpeciesText(value);
  }

  Set<String> _tokens(String value) {
    const stopWords = {
      'what',
      'when',
      'where',
      'which',
      'about',
      'explain',
      'please',
      'does',
      'this',
      'that',
      'with',
      'from',
      'they',
      'are',
      'the',
      'and',
      'how',
      'why',
      'can',
      'you',
    };

    return value
        .split(' ')
        .map((word) => word.trim())
        .where((word) => word.length >= 3 && !stopWords.contains(word))
        .toSet();
  }
}

class OfflineMangroveKnowledgeEntry {
  const OfflineMangroveKnowledgeEntry({
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.relatedSpecies,
    required this.suggestedQuestions,
  });

  final String category;
  final String question;
  final String answer;
  final List<String> keywords;
  final List<String> relatedSpecies;
  final List<String> suggestedQuestions;

  factory OfflineMangroveKnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return OfflineMangroveKnowledgeEntry(
      category: _string(json['category'], fallback: 'general_mangrove'),
      question: _string(json['question']),
      answer: _string(json['answer']),
      keywords: _stringList(json['keywords']),
      relatedSpecies: _stringList(
        json['related_species'] ?? json['relatedSpecies'],
      ).map(canonicalSpeciesName).toList(growable: false),
      suggestedQuestions: _stringList(
        json['suggested_questions'] ?? json['suggestedQuestions'],
      ),
    );
  }

  factory OfflineMangroveKnowledgeEntry.fromSpeciesEducationJson(
    Map<String, dynamic> json,
  ) {
    final scientificName = canonicalSpeciesName(
      json['display_name'] ?? json['scientific_name'],
    );
    final commonName = _string(json['common_name']);
    final family = _string(json['family']);
    final description = _string(json['description']);
    final leaf = _string(json['leaf_characteristics']);
    final root = _string(json['root_characteristics']);
    final physical = _stringList(json['physical_characteristics']);

    final answerParts = <String>[
      description,
      if (leaf.isNotEmpty) 'Leaf: $leaf',
      if (root.isNotEmpty) 'Root: $root',
      if (physical.isNotEmpty)
        'Other identification characteristics: ${physical.join('; ')}.',
    ].where((part) => part.isNotEmpty).toList(growable: false);

    return OfflineMangroveKnowledgeEntry(
      category: 'species_information',
      question: 'How can I identify $scientificName?',
      answer: answerParts.join(' '),
      keywords: [
        scientificName,
        commonName,
        family,
        'identification',
        'mangrove',
      ].where((item) => item.isNotEmpty).toList(growable: false),
      relatedSpecies: [scientificName],
      suggestedQuestions: [
        'Where does $scientificName grow?',
        'What are the leaves and roots of $scientificName?',
        'What is the conservation status of $scientificName?',
      ],
    );
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }
}

class OfflineMangroveKnowledgeAnswer {
  const OfflineMangroveKnowledgeAnswer({
    required this.response,
    required this.intent,
    required this.relatedSpecies,
    required this.suggestedQuestions,
  });

  final String response;
  final String intent;
  final List<String> relatedSpecies;
  final List<String> suggestedQuestions;
}
