import '../../../core/networking/api_contract_exception.dart';
part 'dashboard_response.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.sections,
    required this.freshness,
    this.generatedAt,
  });

  final Map<String, DashboardSection> sections;
  final DashboardFreshness freshness;
  final String? generatedAt;

  /// Validate the legacy default-v1 scaffold separately from operational v2.
  /// Fail closed if that contract changes instead of showing invented queues.
  factory DashboardSnapshot.fromScaffoldResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List || data.isNotEmpty) {
      throw const ApiContractException('dashboard.data');
    }
    final meta = json['meta'];
    if (meta is! Map ||
        !meta.containsKey('next_cursor') ||
        meta['next_cursor'] != null ||
        meta['generated_at'] is! String ||
        (meta['generated_at'] as String).isEmpty) {
      throw const ApiContractException('dashboard.meta');
    }
    final sections = json['sections'];
    if (sections is! Map) {
      throw const ApiContractException('dashboard.sections');
    }
    for (final key in const [
      'notifications',
      'available_tasks',
      'active_tasks',
    ]) {
      final section = sections[key];
      if (section is! Map ||
          section['state'] != 'unavailable' ||
          section['reason'] != 'OPERATIONAL_SCHEMA_DEFERRED' ||
          (section.containsKey('data') &&
              (section['data'] is! List ||
                  (section['data'] as List).isNotEmpty))) {
        throw ApiContractException('dashboard.sections.$key');
      }
    }
    final freshness = json['freshness'];
    if (freshness is! Map ||
        freshness['state'] != 'scaffold' ||
        freshness['reason'] != 'OPERATIONAL_SCHEMA_DEFERRED' ||
        freshness['generated_at'] is! String ||
        (freshness['generated_at'] as String).isEmpty) {
      throw const ApiContractException('dashboard.freshness');
    }
    return DashboardSnapshot.fromJson(json);
  }

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final sections = <String, DashboardSection>{};

    if (rawSections is Map) {
      for (final entry in rawSections.entries) {
        if (entry.value is Map) {
          sections[entry.key.toString()] = DashboardSection.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    final rawFreshness = json['freshness'];
    final freshness = rawFreshness is Map
        ? DashboardFreshness.fromJson(Map<String, dynamic>.from(rawFreshness))
        : const DashboardFreshness(state: DashboardFreshnessState.unknown);

    final generatedAt = json['meta'] is Map
        ? (json['meta'] as Map)['generated_at']?.toString()
        : null;

    return DashboardSnapshot(
      sections: sections,
      freshness: freshness,
      generatedAt: generatedAt,
    );
  }

  factory DashboardSnapshot.fromResponse(Map<String, dynamic> json) =>
      parseDashboardResponse(json);

  bool get operational =>
      freshness.state == DashboardFreshnessState.fresh ||
      freshness.state == DashboardFreshnessState.partial;

  DashboardSnapshot retainingFailedSections(DashboardSnapshot? previous) {
    if (previous == null || !operational || !previous.operational) return this;
    return DashboardSnapshot(
      sections: {
        for (final entry in sections.entries)
          entry.key:
              entry.value.state == DashboardSectionState.failed &&
                  previous.section(entry.key).items.isNotEmpty
              ? DashboardSection(
                  state: DashboardSectionState.stale,
                  reason: entry.value.reason,
                  items: previous.section(entry.key).items,
                  generatedAt: previous.section(entry.key).generatedAt,
                  hasMore: previous.section(entry.key).hasMore,
                )
              : entry.value,
      },
      freshness: freshness,
      generatedAt: generatedAt,
    );
  }

  DashboardSection section(String key) {
    return sections[key] ??
        const DashboardSection(state: DashboardSectionState.unknown);
  }
}

enum DashboardSectionState {
  available,
  empty,
  unavailable,
  stale,
  failed,
  unknown,
}

class DashboardSection {
  const DashboardSection({
    required this.state,
    this.reason,
    this.items = const <Map<String, dynamic>>[],
    this.generatedAt,
    this.hasMore = false,
  });

  final DashboardSectionState state;
  final String? reason;
  final List<Map<String, dynamic>> items;
  final String? generatedAt;
  final bool hasMore;

  factory DashboardSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return DashboardSection(
      state: _parseSectionState(json['state']),
      reason: json['reason']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      hasMore: json['has_more'] == true,
      items: items,
    );
  }
}

enum DashboardFreshnessState { fresh, partial, stale, scaffold, unknown }

class DashboardFreshness {
  const DashboardFreshness({
    required this.state,
    this.reason,
    this.generatedAt,
  });

  final DashboardFreshnessState state;
  final String? reason;
  final String? generatedAt;

  factory DashboardFreshness.fromJson(Map<String, dynamic> json) {
    return DashboardFreshness(
      state: _parseFreshnessState(json['state']),
      reason: json['reason']?.toString(),
      generatedAt: json['generated_at']?.toString(),
    );
  }
}

DashboardSectionState _parseSectionState(Object? value) {
  return switch (value) {
    'available' => DashboardSectionState.available,
    'empty' => DashboardSectionState.empty,
    'unavailable' => DashboardSectionState.unavailable,
    'stale' => DashboardSectionState.stale,
    'failed' => DashboardSectionState.failed,
    _ => DashboardSectionState.unknown,
  };
}

DashboardFreshnessState _parseFreshnessState(Object? value) {
  return switch (value) {
    'fresh' => DashboardFreshnessState.fresh,
    'partial' => DashboardFreshnessState.partial,
    'stale' => DashboardFreshnessState.stale,
    'scaffold' => DashboardFreshnessState.scaffold,
    _ => DashboardFreshnessState.unknown,
  };
}
