import 'package:flutter/material.dart';

/// Owns field anchors and focus for an ordered, scrollable form.
class FormFieldNavigation {
  final _fields = <String, GlobalKey<FormFieldState<dynamic>>>{};
  final _anchors = <String, GlobalKey>{};
  final _focusNodes = <String, FocusNode>{};
  bool _isDisposed = false;

  GlobalKey<FormFieldState<dynamic>> fieldKey(String name) =>
      _fields.putIfAbsent(name, () => GlobalKey<FormFieldState<dynamic>>());

  GlobalKey anchorKey(String name) =>
      _anchors.putIfAbsent(name, () => GlobalKey());

  FocusNode focusNode(String name) =>
      _focusNodes.putIfAbsent(name, () => FocusNode(debugLabel: name));

  Future<void> revealFirstError(
    List<String> order, {
    Map<String, List<String>> errors = const {},
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (_isDisposed) return;
    final normalizedErrors = <String>{
      for (final name in errors.keys) _normalize(name),
    };
    for (final name in order) {
      if (_fields[name]?.currentState?.hasError != true &&
          !normalizedErrors.contains(name)) {
        continue;
      }
      var target = name;
      var context = _context(target);
      // A cascading selector may be hidden until its prerequisite is chosen.
      if (context == null && name.startsWith('address.')) {
        for (final prerequisite in order.where(
          (name) => name.startsWith('address.'),
        )) {
          context = _context(prerequisite);
          if (context != null) {
            target = prerequisite;
            break;
          }
        }
      }
      if (context == null || !context.mounted) continue;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _focusNodes[target]?.requestFocus();
      await Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
  }

  BuildContext? _context(String name) =>
      _fields[name]?.currentContext ?? _anchors[name]?.currentContext;

  String _normalize(String name) {
    final normalized = name.replaceAll('[', '.').replaceAll(']', '');
    if (const {
      'region',
      'province',
      'city_municipality',
      'barangay',
      'postal_code',
      'address_line_1',
      'address_line_2',
    }.contains(normalized)) {
      return 'address.$normalized';
    }
    return normalized;
  }

  void dispose() {
    _isDisposed = true;
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _fields.clear();
    _anchors.clear();
    _focusNodes.clear();
  }
}
