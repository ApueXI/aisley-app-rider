part of 'dashboard_models.dart';

DashboardSnapshot parseDashboardResponse(Map<String, dynamic> json) {
  final rawFreshness = json['freshness'];
  if (rawFreshness is Map && rawFreshness['state'] == 'scaffold') {
    return DashboardSnapshot.fromScaffoldResponse(json);
  }
  final meta = json['meta'],
      sections = json['sections'],
      freshness = json['freshness'];
  if (json['data'] is! List ||
      (json['data'] as List).isNotEmpty ||
      meta is! Map ||
      meta['version'] != 2 ||
      meta['next_cursor'] != null ||
      DateTime.tryParse(meta['generated_at']?.toString() ?? '') == null ||
      sections is! Map ||
      freshness is! Map ||
      !const ['fresh', 'partial'].contains(freshness['state']) ||
      freshness['generated_at'] != meta['generated_at'] ||
      freshness['reason'] != null) {
    throw const ApiContractException('dashboard.aggregate');
  }
  var failed = false;
  for (final key in const [
    'notifications',
    'available_tasks',
    'active_tasks',
  ]) {
    final value = sections[key];
    if (value is! Map ||
        !const ['available', 'empty', 'failed'].contains(value['state']) ||
        value['data'] is! List ||
        (value['data'] as List).length > 5 ||
        value['has_more'] is! bool) {
      throw ApiContractException('dashboard.sections.$key');
    }
    final rows = value['data'] as List;
    if (value['state'] == 'failed') {
      failed = true;
      if (value['reason'] != 'SECTION_UNAVAILABLE' ||
          rows.isNotEmpty ||
          value['generated_at'] != null ||
          value['has_more'] != false) {
        throw ApiContractException('dashboard.sections.$key');
      }
    } else if (value['reason'] != null ||
        value['generated_at'] != meta['generated_at'] ||
        (value['state'] == 'empty') != rows.isEmpty ||
        rows.isEmpty && value['has_more'] == true) {
      throw ApiContractException('dashboard.sections.$key');
    }
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          (row['id'] as String).isEmpty) {
        throw ApiContractException('dashboard.sections.$key.row');
      }
      if (key == 'notifications') {
        if (row['title'] is! String ||
            row['summary'] is! String ||
            !seen.add(row['id'] as String)) {
          throw const ApiContractException('dashboard.notification');
        }
      } else {
        final leg = row['leg'];
        final states = leg == 'first_mile'
            ? (key == 'available_tasks' ? ['assigned'] : ['accepted'])
            : leg == 'final_mile'
            ? (key == 'available_tasks'
                  ? ['delivery_assigned']
                  : [
                      'delivery_accepted',
                      'picked_up_from_hub',
                      'in_transit',
                      'out_for_delivery',
                    ])
            : <String>[];
        if (!states.contains(row['status']) ||
            DateTime.tryParse(row['created_at']?.toString() ?? '') == null ||
            !seen.add('$leg/${row['id']}')) {
          throw const ApiContractException('dashboard.task');
        }
        for (final field in [
          'order_reference',
          'waybill_reference',
          'schedule_id',
        ]) {
          if (row[field] != null && row[field] is! String) {
            throw const ApiContractException('dashboard.task');
          }
        }
        if (row['revision'] != null &&
            (row['revision'] is! int || (row['revision'] as int) < 0)) {
          throw const ApiContractException('dashboard.task.revision');
        }
      }
    }
  }
  if ((freshness['state'] == 'partial') != failed) {
    throw const ApiContractException('dashboard.freshness');
  }
  return DashboardSnapshot.fromJson(json);
}
