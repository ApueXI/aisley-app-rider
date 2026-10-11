import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

Map<String, dynamic> example() => jsonDecode(
  File('docs/features/courier/dashboard/aggregate-example.json')
      .readAsStringSync(),
) as Map<String, dynamic>;
void main() {
  test('versioned fixture supplies separate offered and active legs without a fabricated total', () {
    final snapshot = DashboardSnapshot.fromResponse(example());
    expect(snapshot.operational, isTrue);
    expect(
      snapshot.section('available_tasks').items.single['leg'],
      'first_mile',
    );
    expect(
      snapshot.section('active_tasks').items.single['status'],
      'in_transit',
    );
  });
  test('failed section retains only same-session earlier rows as stale', () {
    final first = DashboardSnapshot.fromResponse(example());
    final raw = example();
    raw['sections']['active_tasks'] = {
      'state': 'failed',
      'reason': 'SECTION_UNAVAILABLE',
      'data': [],
      'has_more': false,
      'generated_at': null,
    };
    raw['freshness']['state'] = 'partial';
    final snapshot = DashboardSnapshot.fromResponse(raw)
        .retainingFailedSections(first);
    expect(snapshot.section('active_tasks').state, DashboardSectionState.stale);
    expect(
      snapshot.section('active_tasks').items.single['status'],
      'in_transit',
    );
    expect(
      snapshot.section('available_tasks').state,
      DashboardSectionState.available,
    );
  });
  for (final field in [
    'version',
    'status',
    'oversized',
    'freshness',
    'empty',
    'timestamp',
    'reason',
    'duplicate',
  ]) {
    test('rejects malformed aggregate $field rather than enabling work', () {
      final raw = example();
      switch (field) {
        case 'version':
          raw['meta']['version'] = 3;
        case 'status':
          raw['sections']['available_tasks']['data'][0]['status'] = 'delivered';
        case 'oversized':
          raw['sections']['available_tasks']['data'] = List.filled(
            6,
            raw['sections']['available_tasks']['data'][0],
          );
        case 'freshness':
          raw['freshness']['state'] = 'scaffold';
        case 'timestamp':
          raw['sections']['active_tasks']['generated_at'] = 'old';
        case 'reason':
          raw['sections']['active_tasks']['reason'] = 'unknown';
        case 'duplicate':
          raw['sections']['active_tasks']['data'].add(
            raw['sections']['active_tasks']['data'][0],
          );
        case 'empty':
          raw['sections']['available_tasks']['state'] = 'empty';
      }
      expect(
        () => DashboardSnapshot.fromResponse(raw),
        throwsA(isA<ApiContractException>()),
      );
    });
  }
}
